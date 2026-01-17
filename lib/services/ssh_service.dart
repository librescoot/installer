import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
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

/// Service for SSH communication with MDB/DBC devices
class SshService {
  static const String mdbHost = '192.168.7.1';
  static const String dbcHost = '192.168.7.2';
  static const int sshPort = 22;
  static const String sshUser = 'root';
  static const Duration connectionTimeout = Duration(seconds: 10);

  SSHClient? _client;
  Map<String, String>? _passwords;

  /// Load version-specific passwords from assets
  Future<void> loadPasswords(String assetsPath) async {
    final passwordsFile = File(path.join(assetsPath, 'passwords.yml'));
    if (!await passwordsFile.exists()) {
      throw Exception('passwords.yml not found at $assetsPath');
    }

    final content = await passwordsFile.readAsString();
    final yaml = loadYaml(content) as YamlMap;

    _passwords = {};
    for (final entry in yaml.entries) {
      final version = entry.key.toString();
      final encoded = entry.value.toString();
      // Passwords are base64 encoded
      _passwords![version] = utf8.decode(base64.decode(encoded));
    }
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
    // Get SSH banner to detect version
    final socket = await SSHSocket.connect(
      host,
      sshPort,
      timeout: connectionTimeout,
    );

    // Try to get version from SSH greeting - use default if not available
    // The version is typically embedded in the SSH banner after connection
    String version = 'v1.20'; // Default to latest

    _client = SSHClient(
      socket,
      username: sshUser,
      onPasswordRequest: () => _getPasswordForVersion(version),
    );

    // After connection, try to detect version from system
    try {
      final osRelease = await runCommand('cat /etc/os-release 2>/dev/null | grep VERSION_ID');
      final match = RegExp(r'VERSION_ID="?([^"]+)"?').firstMatch(osRelease);
      if (match != null) {
        version = 'v${match.group(1)}';
      }
    } catch (_) {}

    // Get serial number
    String? serial;
    try {
      final result = await runCommand('cat /sys/fsl_otp/HW_OCOTP_CFG0 /sys/fsl_otp/HW_OCOTP_CFG1 2>/dev/null | tr -d "\\n"');
      if (result.isNotEmpty) {
        serial = result.trim();
      }
    } catch (_) {}

    return DeviceInfo(
      host: host,
      firmwareVersion: version,
      serialNumber: serial,
    );
  }

  String _getPasswordForVersion(String version) {
    if (_passwords == null) {
      throw Exception('Passwords not loaded. Call loadPasswords() first.');
    }

    // Try exact match first
    if (_passwords!.containsKey(version)) {
      return _passwords![version]!;
    }

    // Try to find closest version
    final versionNum = double.tryParse(version.replaceFirst('v', '')) ?? 0;
    String? closestVersion;
    double closestDiff = double.infinity;

    for (final key in _passwords!.keys) {
      final keyNum = double.tryParse(key.replaceFirst('v', '')) ?? 0;
      final diff = (keyNum - versionNum).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestVersion = key;
      }
    }

    if (closestVersion != null) {
      return _passwords![closestVersion]!;
    }

    throw Exception('No password found for version $version');
  }

  /// Run a command on the connected device
  Future<String> runCommand(String command) async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    final session = await _client!.execute(command);
    final output = StringBuffer();
    await for (final data in session.stdout) {
      output.write(utf8.decode(data));
    }
    await session.done;

    return output.toString();
  }

  /// Upload a file to the device
  Future<void> uploadFile(Uint8List content, String remotePath) async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    // Use cat to write file content via stdin
    final session = await _client!.execute('cat > $remotePath');
    session.stdin.add(content);
    await session.stdin.close();
    await session.done;

    // Make executable if needed
    if (remotePath.endsWith('.sh') || remotePath.contains('fw_setenv')) {
      await runCommand('chmod +x $remotePath');
    }
  }

  /// Upload fw_setenv and configure bootloader for mass storage mode
  Future<void> configureMassStorageMode() async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    // Upload fw_setenv binary and config
    // These should be bundled in assets
    // For now, assume they're already on the device or we use the existing ones

    // Set bootloader variables for USB mass storage mode
    final commands = [
      'fw_setenv bootcmd "ums 0 mmc 1"',
      'fw_setenv bootdelay 0',
    ];

    for (final cmd in commands) {
      final result = await runCommand(cmd);
      if (result.contains('error') || result.contains('Error')) {
        throw Exception('Failed to run: $cmd');
      }
    }
  }

  /// Reboot the device
  Future<void> reboot() async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    try {
      // Reboot command - connection will drop
      await runCommand('reboot');
    } catch (_) {
      // Expected - connection will drop during reboot
    }

    disconnect();
  }

  /// Disconnect from device
  void disconnect() {
    _client?.close();
    _client = null;
  }

  bool get isConnected => _client != null;
}
