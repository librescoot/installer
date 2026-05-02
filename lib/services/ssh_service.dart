import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/scooter_health.dart';
import '../models/trampoline_status.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

/// SSH connection info for a device
class DeviceInfo {
  final String host;
  final String firmwareVersion;
  final String? serialNumber;

  DeviceInfo({
    required this.host,
    required this.firmwareVersion,
    this.serialNumber,
  });
}

/// Callback used to obtain a manually-entered root password when neither the
/// empty password nor the bundled device-config credential authenticates.
/// [version] is the firmware version we believe the device is running (or
/// null if undetectable). [previousAttempts] is how many manual passwords
/// have already been tried this session. Return null/empty string to give up.
typedef ManualPasswordPrompt = Future<String?> Function({
  required String? version,
  required int previousAttempts,
});

/// Service for SSH communication with MDB/DBC devices
class SshService {
  static const String mdbHost = '192.168.7.1';
  static const String dbcHost = '192.168.7.2';
  static const int sshPort = 22;
  static const String sshUser = 'root';
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const int maxManualPasswordAttempts = 3;

  SSHClient? _client;
  Map<String, String>? _deviceConfig;
  bool _sftpAvailable = false;
  ManualPasswordPrompt? _manualPasswordPrompt;

  /// Auth key injected at build time via --dart-define=AUTH_KEY=...
  static const _authKey = String.fromEnvironment('AUTH_KEY');

  /// Load device configuration from encrypted or plaintext asset.
  Future<void> loadDeviceConfig(String assetsPath) async {
    String yamlContent;

    if (_authKey.isNotEmpty) {
      try {
        final data = await rootBundle.load('$assetsPath/device_configs.bin');
        debugPrint('SSH: loading device profile (bundle)');
        yamlContent = _decryptAsset(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      } catch (_) {
        final encFile = File(path.join(assetsPath, 'device_configs.bin'));
        if (await encFile.exists()) {
          debugPrint('SSH: loading device profile (filesystem)');
          yamlContent = _decryptAsset(await encFile.readAsBytes());
        } else {
          yamlContent = '';
        }
      }
    } else {
      yamlContent = '';
    }

    if (yamlContent.isEmpty) {
      final plainFile = File(path.join(assetsPath, 'device_configs.yml'));
      if (await plainFile.exists()) {
        debugPrint('SSH: loading device profile (dev fallback)');
        yamlContent = await plainFile.readAsString();
      } else {
        debugPrint('SSH: no device profile available, will use defaults');
        _deviceConfig = {};
        return;
      }
    }

    final yaml = loadYaml(yamlContent) as YamlMap;
    _deviceConfig = {};
    for (final entry in yaml.entries) {
      final version = entry.key.toString();
      final encoded = entry.value.toString();
      final decodedRaw = utf8.decode(base64.decode(encoded));
      _deviceConfig![version] = decodedRaw.trim();
    }
    debugPrint('SSH: device profile loaded (${_deviceConfig!.length} entries)');
  }

  /// Decrypt AES-256-CBC with IV prepended, PKCS7 padding.
  String _decryptAsset(Uint8List encrypted) {
    final keyBytes = Uint8List.fromList(
      utf8.encode(_authKey).take(32).toList()
        ..addAll(List.filled(32 - _authKey.length.clamp(0, 32), 0)),
    );
    final iv = encrypted.sublist(0, 16);
    final ciphertext = encrypted.sublist(16);

    final cipher = pc.CBCBlockCipher(pc.AESEngine())
      ..init(false, pc.ParametersWithIV(pc.KeyParameter(keyBytes), iv));

    final padded = Uint8List(ciphertext.length);
    var offset = 0;
    while (offset < ciphertext.length) {
      offset += cipher.processBlock(ciphertext, offset, padded, offset);
    }

    // Remove PKCS7 padding
    final padLen = padded.last;
    final unpadded = padded.sublist(0, padded.length - padLen);

    return utf8.decode(unpadded);
  }

  /// Set a callback to be invoked when the bundled credentials don't work
  /// and we need to ask the user for the root password. Only the initial
  /// MDB connect on stock firmware needs this — once Librescoot is flashed
  /// the password is empty.
  void setManualPasswordPrompt(ManualPasswordPrompt? prompt) {
    _manualPasswordPrompt = prompt;
  }

  /// Connect to MDB and detect firmware version
  Future<DeviceInfo> connectToMdb() async {
    return _connect(mdbHost);
  }

  /// Connect to DBC via MDB jump host
  Future<DeviceInfo> connectToDbc() async {
    // First ensure we're connected to MDB
    if (_client == null) {
      await connectToMdb();
    }

    // Connect to DBC through MDB
    return _connect(dbcHost);
  }

  Future<DeviceInfo> _connect(String host) async {
    // Auth strategy:
    //   1. empty password (Librescoot)
    //   2. bundled credential matched against banner version (stock OS)
    //   3. user-supplied password via manual prompt callback (unknown stock)
    var authVersion = 'v1.20';
    var stage = 0; // 0 = empty, 1 = bundled, 2 = manual
    var manualAttempts = 0;
    String? manualPassword;

    while (true) {
      final socket = await SSHSocket.connect(
        host,
        sshPort,
        timeout: connectionTimeout,
      );
      debugPrint('SSH: connected socket to $host:$sshPort');

      var bannerVersionSeen = authVersion;
      _client = SSHClient(
        socket,
        username: sshUser,
        onPasswordRequest: () {
          if (stage == 0) {
            debugPrint('SSH: attempting default device configuration');
            return '';
          }
          if (stage == 1) {
            // Stage 0 already verified this version has a non-empty bundled
            // credential before transitioning here.
            final credential = _resolveDeviceCredential(authVersion);
            debugPrint('SSH: attempting bundled device configuration for version $authVersion');
            return credential;
          }
          debugPrint('SSH: attempting user-supplied configuration (attempt $manualAttempts)');
          return manualPassword ?? '';
        },
        onUserauthBanner: (banner) {
          final bannerVersion = _extractVersionFromText(banner);
          if (bannerVersion != null) {
            bannerVersionSeen = bannerVersion;
            authVersion = bannerVersion;
            debugPrint('SSH: parsed version from banner -> $authVersion');
          }
        },
      );

      try {
        await _client!.authenticated;
        debugPrint('SSH: authentication successful');
        break;
      } catch (e) {
        debugPrint('SSH: authentication failed: $e');
        _client?.close();
        _client = null;

        if (stage == 0) {
          if (bannerVersionSeen != 'v1.20') {
            authVersion = bannerVersionSeen;
            // Skip stage 1 if the bundled lookup would just return empty
            // (which we already tried) or has no entry at all.
            String? bundled;
            try {
              bundled = _resolveDeviceCredential(authVersion);
            } catch (_) {
              bundled = null;
            }
            if (bundled != null && bundled.isNotEmpty) {
              stage = 1;
              debugPrint('SSH: default configuration not accepted, attempting bundled device configuration for $authVersion');
              continue;
            }
            debugPrint('SSH: no bundled device configuration for $authVersion, prompting user');
          }
          stage = 2;
        } else if (stage == 1) {
          stage = 2;
        }

        if (stage == 2 && _manualPasswordPrompt != null && manualAttempts < maxManualPasswordAttempts) {
          final entered = await _manualPasswordPrompt!(
            version: bannerVersionSeen != 'v1.20' ? bannerVersionSeen : null,
            previousAttempts: manualAttempts,
          );
          if (entered == null || entered.isEmpty) {
            debugPrint('SSH: user cancelled manual configuration prompt');
            rethrow;
          }
          manualPassword = entered;
          manualAttempts++;
          debugPrint('SSH: retrying with user-supplied configuration (attempt $manualAttempts)');
          continue;
        }

        rethrow;
      }
    }

    // Stop power manager to prevent suspend/hibernate during flashing
    try {
      await runCommand('systemctl stop librescoot-pm 2>/dev/null; systemctl stop pm-service 2>/dev/null; systemctl stop unu-pm 2>/dev/null; true');
      debugPrint('SSH: stopped power manager');
    } catch (_) {}

    // Check if SFTP subsystem is available (stock scooterOS doesn't have it)
    try {
      final sftpCheck = (await runCommand('test -e /usr/libexec/sftp-server -o -e /usr/lib/openssh/sftp-server && echo yes || echo no')).trim();
      _sftpAvailable = sftpCheck == 'yes';
      debugPrint('SSH: SFTP ${_sftpAvailable ? "available" : "not available"}');
    } catch (_) {
      _sftpAvailable = false;
    }

    final detectedVersion = await _detectFirmwareVersion();
    if (detectedVersion != null) {
      authVersion = detectedVersion;
      debugPrint('SSH: detected firmware version $detectedVersion');
    } else {
      debugPrint('SSH: firmware version detection failed, using Unknown for UI');
    }

    // Get serial number
    String? serial;
    try {
      final result = await runCommand('cat /sys/fsl_otp/HW_OCOTP_CFG0 /sys/fsl_otp/HW_OCOTP_CFG1 2>/dev/null');
      serial = _parseSerial(result);
      if (serial != null) {
        debugPrint('SSH: parsed serial $serial');
      }
    } catch (e) {
      debugPrint('SSH: serial read failed: $e');
    }

    return DeviceInfo(
      host: host,
      firmwareVersion: detectedVersion ?? 'Unknown',
      serialNumber: serial,
    );
  }

  Future<String?> _detectFirmwareVersion() async {
    if (_client == null) return null;

    final versionIdRegex = RegExp(r'^VERSION_ID="?([^"\n]+)"?$', multiLine: true);
    final semverRegex = RegExp(r'\bv?(\d+\.\d+(?:\.\d+)?)\b');

    final commands = <String>[
      'cat /etc/os-release 2>/dev/null',
      'cat /etc/librescoot-release 2>/dev/null',
      'cat /etc/issue 2>/dev/null',
    ];

    for (final command in commands) {
      try {
        debugPrint('SSH: checking firmware version via `$command`');
        final output = await runCommand(command);

        final versionIdMatch = versionIdRegex.firstMatch(output);
        if (versionIdMatch != null) {
          final version = _normalizeVersion(versionIdMatch.group(1)!);
          debugPrint('SSH: parsed VERSION_ID -> $version');
          return version;
        }

        final semverMatch = semverRegex.firstMatch(output);
        if (semverMatch != null) {
          final version = _normalizeVersion(semverMatch.group(1)!);
          debugPrint('SSH: parsed semver -> $version');
          return version;
        }

        debugPrint('SSH: no version match from command output');
      } catch (e) {
        debugPrint('SSH: command failed during version detection: $e');
        continue;
      }
    }

    return null;
  }

  String _normalizeVersion(String raw) {
    final trimmed = raw.trim();
    // Only add 'v' prefix for semver-like versions (e.g. 1.15.0), not channel tags
    if (trimmed.startsWith('v') || !RegExp(r'^\d').hasMatch(trimmed)) {
      return trimmed;
    }
    return 'v$trimmed';
  }

  String? _extractVersionFromText(String text) {
    final match = RegExp(r'\bv?(\d+\.\d+(?:\.\d+)?)\b').firstMatch(text);
    if (match == null) return null;
    return _normalizeVersion(match.group(1)!);
  }

  double _versionToNumber(String version) {
    final clean = version.trim().toLowerCase().replaceFirst('v', '');
    final parts = clean.split('.');
    final major = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final patch = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return (major * 1000000) + (minor * 1000) + patch.toDouble();
  }

  String _resolveDeviceCredential(String version) {
    if (_deviceConfig == null || _deviceConfig!.isEmpty) {
      debugPrint('SSH: no device profile available, using default configuration');
      return '';
    }

    final normalized = _normalizeVersion(version);
    debugPrint('SSH: resolving device configuration for version "$version"');

    // Try exact match first
    if (_deviceConfig!.containsKey(normalized)) {
      return _deviceConfig![normalized]!;
    }
    if (_deviceConfig!.containsKey(version)) {
      return _deviceConfig![version]!;
    }
    final withoutV = normalized.replaceFirst('v', '');
    if (_deviceConfig!.containsKey(withoutV)) {
      return _deviceConfig![withoutV]!;
    }

    final parts = withoutV.split('.');
    if (parts.length == 3) {
      final majorMinor = 'v${parts[0]}.${parts[1]}';
      if (_deviceConfig!.containsKey(majorMinor)) {
        return _deviceConfig![majorMinor]!;
      }
    }

    // Try to find closest version
    final versionNum = _versionToNumber(normalized);
    String? closestVersion;
    double closestDiff = double.infinity;

    for (final key in _deviceConfig!.keys) {
      final keyNum = _versionToNumber(key);
      final diff = (keyNum - versionNum).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestVersion = key;
      }
    }

    if (closestVersion != null) {
      debugPrint('SSH: using closest profile entry "$closestVersion"');
      return _deviceConfig![closestVersion]!;
    }

    throw Exception('No device config found for version $version');
  }

  /// Run a command on the connected device
  Future<String> runCommand(String command, {Duration timeout = const Duration(seconds: 60)}) async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    final session = await _client!.execute(command);
    final stdout = StringBuffer();
    final stderr = StringBuffer();

    final stdoutDone = () async {
      await for (final data in session.stdout) {
        stdout.write(utf8.decode(data));
      }
    }();

    final stderrDone = () async {
      await for (final data in session.stderr) {
        stderr.write(utf8.decode(data));
      }
    }();

    await Future.wait([stdoutDone, stderrDone, session.done])
        .timeout(timeout);

    final exitCode = session.exitCode;
    if (exitCode != null && exitCode != 0) {
      throw Exception(
        'Command failed (exit $exitCode): $command'
        '${stderr.isNotEmpty ? '\nstderr: ${stderr.toString().trim()}' : ''}',
      );
    }

    return stdout.toString();
  }

  /// Upload a file to the device via SFTP with progress reporting.
  /// Falls back to cat-over-stdin if SFTP is unavailable.
  Future<void> uploadFile(
    Uint8List content,
    String remotePath, {
    void Function(int bytesSent, int totalBytes)? onProgress,
  }) async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    // Scale timeout with file size: at least 60s, plus 1s per 100KB
    final timeoutSecs = 60 + (content.length / (100 * 1024)).ceil();
    final timeout = Duration(seconds: timeoutSecs);

    if (_sftpAvailable) {
      try {
        await _uploadViaSftp(content, remotePath, onProgress).timeout(timeout);
      } catch (e) {
        debugPrint('SSH: SFTP upload failed ($e), falling back to cat');
        _sftpAvailable = false;
        await _uploadViaCat(content, remotePath).timeout(timeout);
      }
    } else {
      await _uploadViaCat(content, remotePath).timeout(timeout);
    }

    // Make executable if needed
    if (remotePath.endsWith('.sh') || remotePath.contains('fw_setenv')) {
      await runCommand('chmod +x $remotePath');
    }
  }

  Future<void> _uploadViaSftp(
    Uint8List content,
    String remotePath,
    void Function(int bytesSent, int totalBytes)? onProgress,
  ) async {
    final sftp = await _client!.sftp();
    try {
      final file = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.write | SftpFileOpenMode.create | SftpFileOpenMode.truncate,
      );
      try {
        const chunkSize = 64 * 1024;
        final stream = Stream<Uint8List>.fromIterable(
          Iterable.generate(
            (content.length + chunkSize - 1) ~/ chunkSize,
            (i) {
              final start = i * chunkSize;
              final end = (start + chunkSize).clamp(0, content.length);
              return Uint8List.sublistView(content, start, end);
            },
          ),
        );

        final writer = file.write(
          stream,
          onProgress: (total) => onProgress?.call(total, content.length),
        );
        await writer.done;
      } finally {
        await file.close();
      }
    } finally {
      sftp.close();
    }
  }

  Future<void> _uploadViaCat(Uint8List content, String remotePath) async {
    final session = await _client!.execute('cat > $remotePath');
    session.stdin.add(content);
    await session.stdin.close();
    // Drain stdout/stderr to prevent blocking
    final stdoutDone = () async { await for (final _ in session.stdout) {} }();
    final stderrDone = () async { await for (final _ in session.stderr) {} }();
    await Future.wait([stdoutDone, stderrDone, session.done]);
  }

  /// Upload fw_setenv and configure bootloader for mass storage mode
  Future<void> configureMassStorageMode() async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    // Check if the device already has fw_setenv and fw_env.config (Librescoot).
    // If so, use the device's own tools and config (correct env offsets).
    // If not (stock scooterOS), upload our bundled versions.
    final hasNativeFwSetenv = (await runCommand('command -v fw_setenv >/dev/null 2>&1 && echo yes || echo no')).trim() == 'yes';
    final hasNativeConfig = (await runCommand('test -f /etc/fw_env.config && echo yes || echo no')).trim() == 'yes';

    final String fwSetenvCmd;
    final String configFlag;

    if (hasNativeFwSetenv && hasNativeConfig) {
      debugPrint('SSH: using device-native fw_setenv and /etc/fw_env.config');
      fwSetenvCmd = 'fw_setenv';
      configFlag = '';
    } else {
      debugPrint('SSH: uploading bundled fw_setenv and fw_env.config');
      final fwSetenv = await _readToolAsset('fw_setenv');
      final fwEnvConfig = await _readToolAsset('fw_env.config');
      debugPrint('SSH: uploading fw_setenv (${fwSetenv.length} bytes)...');
      await uploadFile(fwSetenv, '/tmp/fw_setenv');
      debugPrint('SSH: uploading fw_env.config (${fwEnvConfig.length} bytes)...');
      await uploadFile(fwEnvConfig, '/tmp/fw_env.config');
      debugPrint('SSH: uploads complete');
      fwSetenvCmd = '/tmp/fw_setenv';
      configFlag = '-c /tmp/fw_env.config';
    }

    // Set bootloader variables for USB mass storage mode.
    // Some boards need fuse programming in bootcmd (legacy).
    // If that fails, fall back to plain UMS bootcmd.
    // Use single quotes so the remote shell passes semicolons through
    // to fw_setenv as a single value argument.
    final fullBootcmd =
        "$fwSetenvCmd $configFlag bootcmd 'fuse prog -y 0 5 0x00002860; "
        "fuse prog -y 0 6 0x00000010; ums 0 mmc 1'";
    final fallbackBootcmd =
        "$fwSetenvCmd $configFlag bootcmd 'ums 0 mmc 1'";

    try {
      debugPrint('SSH: running: $fullBootcmd');
      final result = await runCommand(fullBootcmd);
      debugPrint('SSH: fw_setenv bootcmd result: "$result"');
    } catch (e) {
      debugPrint('SSH: full bootcmd failed ($e), trying fallback...');
      final result = await runCommand(fallbackBootcmd);
      debugPrint('SSH: fallback fw_setenv result: "$result"');
    }

    // Give fw_setenv time to flush to eMMC
    await Future.delayed(const Duration(seconds: 2));

    final delayResult = await runCommand('$fwSetenvCmd $configFlag bootdelay 0');
    debugPrint('SSH: fw_setenv bootdelay result: "$delayResult"');

    // Give fw_setenv time to flush
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('SSH: bootloader configured for mass storage mode');
  }

  /// Reboot the device
  Future<void> reboot() async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    final rebootCommands = <String>[
      'reboot',
      '/sbin/reboot',
      'busybox reboot',
      'shutdown -r now',
    ];

    var requested = false;
    for (final cmd in rebootCommands) {
      try {
        debugPrint('SSH: sending reboot command: $cmd');
        await runCommand(cmd);
        debugPrint('SSH: reboot command accepted: $cmd');
        requested = true;
        break;
      } catch (e) {
        final error = e.toString().toLowerCase();
        if (_looksLikeDisconnect(error)) {
          debugPrint('SSH: reboot likely triggered (connection dropped): $cmd');
          requested = true;
          break;
        }
        debugPrint('SSH: reboot command failed: $cmd -> $e');
      }
    }

    if (!requested) {
      throw Exception('Failed to trigger reboot with known commands');
    }

    debugPrint('SSH: disconnecting local SSH client after reboot attempt');
    disconnect();
  }

  bool _looksLikeDisconnect(String error) {
    return error.contains('connection reset') ||
        error.contains('broken pipe') ||
        error.contains('socket') ||
        error.contains('eof') ||
        error.contains('closed');
  }

  Future<Uint8List> _readToolAsset(String fileName) async {
    final bundleCandidates = <String>[
      'assets/tools/$fileName',
      'assets/binaries/$fileName',
    ];
    for (final candidate in bundleCandidates) {
      try {
        final data = await rootBundle.load(candidate);
        debugPrint('SSH: loaded tool asset from bundle: $candidate');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } catch (_) {
        // Try next candidate
      }
    }

    final candidates = <String>[
      path.join(Directory.current.path, 'assets', 'tools', fileName),
      path.join(Directory.current.path, 'assets', 'binaries', fileName),
      path.join(
        Platform.resolvedExecutable,
        '..',
        'data',
        'flutter_assets',
        'assets',
        'tools',
        fileName,
      ),
      path.join(
        Platform.resolvedExecutable,
        '..',
        'data',
        'flutter_assets',
        'assets',
        'binaries',
        fileName,
      ),
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }

    throw Exception('Required tool asset not found: $fileName');
  }

  String? _parseSerial(String raw) {
    final matches = RegExp(r'0x[0-9a-fA-F]+').allMatches(raw).map((m) => m.group(0)!).toList();
    if (matches.isEmpty) return null;
    return matches.map((part) => part.replaceFirst(RegExp(r'^0x', caseSensitive: false), '')).join().toLowerCase();
  }

  /// Disconnect from device
  void disconnect() {
    _client?.close();
    _client = null;
  }

  bool get isConnected => _client != null;

  /// Run a Redis HGET command on the MDB and return the value.
  Future<String?> redisHget(String hash, String field) async {
    try {
      final result = await runCommand('redis-cli HGET $hash $field');
      final value = result.trim();
      if (value.isEmpty || value == '(nil)') return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Run a Redis LPUSH command on the MDB.
  Future<void> redisLpush(String key, String value) async {
    await runCommand('redis-cli LPUSH $key $value');
  }

  /// Run a Redis HGETALL on the MDB and return all field/value pairs.
  /// Returns an empty map on error or if the hash is empty.
  Future<Map<String, String>> redisHgetall(String hash) async {
    try {
      final result = await runCommand('redis-cli HGETALL $hash');
      final lines = result.split('\n');
      final out = <String, String>{};
      for (var i = 0; i + 1 < lines.length; i += 2) {
        final k = lines[i].trim();
        final v = lines[i + 1].trim();
        if (k.isEmpty) continue;
        out[k] = v;
      }
      return out;
    } catch (_) {
      return const <String, String>{};
    }
  }

  /// Snapshot battery / CBB / aux state to the installer log.
  /// One line per source so the log stays greppable. [tag] identifies
  /// the call site (e.g. 'health-check', 'pre-flash').
  Future<void> logScooterStats(String tag) async {
    final results = await Future.wait([
      redisHgetall('aux-battery'),
      redisHgetall('cb-battery'),
      redisHgetall('battery:0'),
      redisHgetall('battery:1'),
    ]);
    final aux = results[0];
    final cbb = results[1];
    final b0 = results[2];
    final b1 = results[3];

    String fmtAux() {
      if (aux.isEmpty) return 'no-data';
      final v = aux['voltage'];
      final c = aux['charge'];
      final s = aux['charge-status'];
      final parts = <String>[];
      if (v != null) parts.add('V=${v}mV');
      if (c != null) parts.add('charge=$c%');
      if (s != null && s.isNotEmpty) parts.add('status=$s');
      return parts.isEmpty ? 'no-data' : parts.join(' ');
    }

    String fmtCbb() {
      if (cbb.isEmpty) return 'no-data';
      final present = cbb['present'] == 'true';
      if (!present) return 'present=false';
      final parts = <String>['present=true'];
      if (cbb['charge'] != null) parts.add('charge=${cbb['charge']}%');
      if (cbb['state-of-health'] != null) parts.add('soh=${cbb['state-of-health']}%');
      if (cbb['cycle-count'] != null) parts.add('cycles=${cbb['cycle-count']}');
      if (cbb['temperature'] != null) parts.add('temp=${cbb['temperature']}C');
      if (cbb['cell-voltage'] != null) parts.add('V=${cbb['cell-voltage']}uV');
      if (cbb['current'] != null) parts.add('I=${cbb['current']}uA');
      if (cbb['charge-status'] != null && cbb['charge-status']!.isNotEmpty) {
        parts.add('status=${cbb['charge-status']}');
      }
      return parts.join(' ');
    }

    String fmtMain(Map<String, String> b) {
      if (b.isEmpty) return 'no-data';
      final present = b['present'] == 'true';
      if (!present) return 'present=false';
      final parts = <String>['present=true'];
      if (b['state'] != null) parts.add('state=${b['state']}');
      if (b['charge'] != null) parts.add('charge=${b['charge']}%');
      if (b['voltage'] != null) parts.add('V=${b['voltage']}mV');
      if (b['current'] != null) parts.add('I=${b['current']}mA');
      // Pick the hottest cell to keep the line short.
      final temps = <int>[];
      for (var i = 0; i < 4; i++) {
        final t = int.tryParse(b['temperature:$i'] ?? '');
        if (t != null) temps.add(t);
      }
      if (temps.isNotEmpty) parts.add('temp=${temps.reduce((a, b) => a > b ? a : b)}C');
      if (b['temperature-state'] != null) parts.add('temp-state=${b['temperature-state']}');
      if (b['state-of-health'] != null) parts.add('soh=${b['state-of-health']}%');
      if (b['cycle-count'] != null) parts.add('cycles=${b['cycle-count']}');
      if (b['serial-number'] != null && b['serial-number']!.isNotEmpty) {
        parts.add('sn=${b['serial-number']}');
      }
      return parts.join(' ');
    }

    debugPrint('Stats[$tag] aux: ${fmtAux()}');
    debugPrint('Stats[$tag] cbb: ${fmtCbb()}');
    debugPrint('Stats[$tag] battery:0: ${fmtMain(b0)}');
    debugPrint('Stats[$tag] battery:1: ${fmtMain(b1)}');
  }

  /// Get the current vehicle state from Redis.
  Future<String?> getVehicleState() async {
    return redisHget('vehicle', 'state');
  }

  /// Wait for a specific vehicle state, polling every [interval].
  /// Returns true if the state was reached, false on timeout.
  Future<bool> waitForVehicleState(
    String targetState, {
    Duration timeout = const Duration(seconds: 120),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final state = await getVehicleState();
      if (state == targetState) return true;
      await Future.delayed(interval);
    }
    return false;
  }

  /// Query scooter health from Redis.
  Future<ScooterHealth> queryHealth() async {
    final health = ScooterHealth();
    health.auxCharge = int.tryParse(await redisHget('aux-battery', 'charge') ?? '');
    health.cbbStateOfHealth = int.tryParse(await redisHget('cb-battery', 'state-of-health') ?? '');
    health.cbbCharge = int.tryParse(await redisHget('cb-battery', 'charge') ?? '');
    final batteryPresent = await redisHget('battery:0', 'present');
    health.batteryPresent = batteryPresent == 'true';
    return health;
  }

  /// Open the seatbox.
  Future<void> openSeatbox() async {
    await redisLpush('scooter:seatbox', 'open');
  }

  /// Check if CBB is connected.
  Future<bool> isCbbPresent() async {
    final present = await redisHget('cb-battery', 'present');
    return present == 'true';
  }

  /// Check if main battery is present.
  Future<bool> isBatteryPresent() async {
    final present = await redisHget('battery:0', 'present');
    return present == 'true';
  }

  /// Download a remote file's contents via cat. Returns null if the file doesn't exist.
  Future<Uint8List?> downloadFile(String remotePath) async {
    if (_client == null) throw Exception('Not connected');
    try {
      final session = await _client!.execute('cat ${_shellEscape(remotePath)}');
      final chunks = <int>[];
      final stdoutDone = () async {
        await for (final data in session.stdout) {
          chunks.addAll(data);
        }
      }();
      // Must drain stderr to prevent the session from blocking
      final stderrDone = () async {
        await for (final _ in session.stderr) {}
      }();
      await Future.wait([stdoutDone, stderrDone, session.done])
          .timeout(const Duration(seconds: 30));
      if (session.exitCode != 0) return null;
      return Uint8List.fromList(chunks);
    } catch (_) {
      return null;
    }
  }

  /// List files in a remote directory. Returns empty list if directory doesn't exist.
  Future<List<String>> listRemoteDir(String remotePath) async {
    try {
      final output = await runCommand('ls -1 ${_shellEscape(remotePath)} 2>/dev/null');
      return output.trim().split('\n').where((l) => l.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  String _shellEscape(String s) => "'${s.replaceAll("'", "'\\''")}'";

  /// Back up radio-gaga config from the MDB to a local directory.
  /// Checks both Librescoot (/data/radio-gaga/) and stock (/etc/rescoot/) paths.
  /// Returns the backup directory path, or null if no config was found.
  Future<String?> backupRadioGagaConfig(String backupBaseDir) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final backupDir = Directory(path.join(backupBaseDir, 'radio-gaga-backup-$timestamp'));

    var found = false;

    // Librescoot path: /data/radio-gaga/config.yaml + any referenced certs
    final lsConfig = await downloadFile('/data/radio-gaga/config.yaml');
    if (lsConfig != null && lsConfig.isNotEmpty) {
      final targetDir = Directory(path.join(backupDir.path, 'data-radio-gaga'));
      await targetDir.create(recursive: true);
      await File(path.join(targetDir.path, 'config.yaml')).writeAsBytes(lsConfig);
      debugPrint('SSH: backed up /data/radio-gaga/config.yaml');
      found = true;

      // Also back up any referenced cert files
      try {
        final yamlStr = utf8.decode(lsConfig);
        final yaml = loadYaml(yamlStr);
        if (yaml is Map) {
          final mqtt = yaml['mqtt'];
          if (mqtt is Map) {
            final caCertPath = mqtt['ca_cert'] as String?;
            if (caCertPath != null && caCertPath.isNotEmpty) {
              final certData = await downloadFile(caCertPath);
              if (certData != null && certData.isNotEmpty) {
                final certFilename = path.basename(caCertPath);
                await File(path.join(targetDir.path, certFilename)).writeAsBytes(certData);
                debugPrint('SSH: backed up CA cert $caCertPath');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('SSH: failed to parse LS config for cert paths: $e');
      }
    }

    // Stock scooterOS paths
    const stockPaths = [
      '/etc/rescoot/radio-gaga.yml',
      '/home/root/radio-gaga/radio-gaga.yml',
    ];
    for (final stockPath in stockPaths) {
      final stockConfig = await downloadFile(stockPath);
      if (stockConfig == null || stockConfig.isEmpty) continue;

      final targetDir = Directory(path.join(backupDir.path, 'etc-rescoot'));
      await targetDir.create(recursive: true);
      await File(path.join(targetDir.path, 'radio-gaga.yml')).writeAsBytes(stockConfig);
      debugPrint('SSH: backed up $stockPath');
      found = true;

      // Parse YAML to find referenced files (e.g. mqtt.ca_cert) and back those up too
      try {
        final yamlStr = utf8.decode(stockConfig);
        final yaml = loadYaml(yamlStr);
        if (yaml is Map) {
          final mqtt = yaml['mqtt'];
          if (mqtt is Map) {
            final caCertPath = mqtt['ca_cert'] as String?;
            if (caCertPath != null && caCertPath.isNotEmpty) {
              final certData = await downloadFile(caCertPath);
              if (certData != null && certData.isNotEmpty) {
                final certFilename = path.basename(caCertPath);
                await File(path.join(targetDir.path, certFilename)).writeAsBytes(certData);
                debugPrint('SSH: backed up CA cert $caCertPath');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('SSH: failed to parse stock config for cert paths: $e');
      }
      break; // found one, no need to check others
    }

    if (!found) {
      debugPrint('SSH: no radio-gaga config found to back up');
      return null;
    }

    debugPrint('SSH: radio-gaga config backed up to ${backupDir.path}');
    return backupDir.path;
  }

  /// Restore a backed-up radio-gaga config to /data/radio-gaga/ on the MDB.
  /// Handles stock configs by rewriting ca_cert paths to /data/radio-gaga/.
  Future<bool> restoreRadioGagaConfig(String backupPath) async {
    final backupDir = Directory(backupPath);
    if (!await backupDir.exists()) return false;

    await runCommand('mkdir -p /data/radio-gaga');

    // Prefer Librescoot backup (already in the right format)
    final librescootDir = Directory(path.join(backupPath, 'data-radio-gaga'));
    if (await librescootDir.exists()) {
      for (final file in await librescootDir.list().toList()) {
        if (file is! File) continue;
        final filename = path.basename(file.path);
        final data = await file.readAsBytes();
        await uploadFile(Uint8List.fromList(data), '/data/radio-gaga/$filename');
        debugPrint('SSH: restored /data/radio-gaga/$filename');
      }
      return true;
    }

    // Stock backup — needs path rewriting
    final stockDir = Directory(path.join(backupPath, 'etc-rescoot'));
    if (!await stockDir.exists()) return false;

    final configFile = File(path.join(stockDir.path, 'radio-gaga.yml'));
    if (!await configFile.exists()) return false;

    // Upload any non-YAML files first (certs, keys)
    for (final file in await stockDir.list().toList()) {
      if (file is! File) continue;
      final filename = path.basename(file.path);
      if (filename == 'radio-gaga.yml') continue;
      final data = await file.readAsBytes();
      await uploadFile(Uint8List.fromList(data), '/data/radio-gaga/$filename');
      debugPrint('SSH: restored /data/radio-gaga/$filename');
    }

    // Rewrite ca_cert path in the config and upload
    var configContent = await configFile.readAsString();
    try {
      final yaml = loadYaml(configContent);
      if (yaml is Map) {
        final mqtt = yaml['mqtt'];
        if (mqtt is Map) {
          final caCertPath = mqtt['ca_cert'] as String?;
          if (caCertPath != null && caCertPath.isNotEmpty) {
            final certFilename = path.basename(caCertPath);
            final newPath = '/data/radio-gaga/$certFilename';
            configContent = configContent.replaceAll(caCertPath, newPath);
            debugPrint('SSH: rewrote ca_cert path: $caCertPath → $newPath');
          }
        }
      }
    } catch (e) {
      debugPrint('SSH: failed to rewrite cert paths, uploading config as-is: $e');
    }

    await uploadFile(
      Uint8List.fromList(utf8.encode(configContent)),
      '/data/radio-gaga/config.yaml',
    );
    debugPrint('SSH: restored /data/radio-gaga/config.yaml (converted from stock)');
    return true;
  }

  /// Read the trampoline status file from MDB.
  Future<TrampolineStatus> readTrampolineStatus() async {
    try {
      final content = await runCommand('cat /data/trampoline-status 2>/dev/null');
      if (content.trim().isEmpty) {
        return TrampolineStatus(result: TrampolineResult.unknown);
      }
      return TrampolineStatus.parse(content);
    } catch (_) {
      return TrampolineStatus(result: TrampolineResult.unknown);
    }
  }
}
