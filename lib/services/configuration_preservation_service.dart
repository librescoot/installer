import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import '../models/configuration_preservation.dart';
import 'ssh_service.dart';

typedef ConfigurationCommandRunner = Future<String> Function(String command);
typedef ConfigurationDownloader =
    Future<Uint8List?> Function(String remotePath);
typedef ConfigurationUploader =
    Future<void> Function(Uint8List content, String remotePath);

class ConfigurationPreservationService {
  ConfigurationPreservationService(SshService ssh)
    : this.withTransport(
        runCommand: ssh.runCommand,
        download: ssh.downloadFile,
        upload: ssh.uploadFile,
      );

  @visibleForTesting
  ConfigurationPreservationService.withTransport({
    required ConfigurationCommandRunner runCommand,
    required ConfigurationDownloader download,
    required ConfigurationUploader upload,
  }) : _runCommand = runCommand,
       _download = download,
       _upload = upload;

  final ConfigurationCommandRunner _runCommand;
  final ConfigurationDownloader _download;
  final ConfigurationUploader _upload;

  static const _fixedPaths = <String>[
    '/var/rootdirs/home/root/scooter-id',
    '/home/root/scooter-id',
    '/data/root/scooter-id',
    '/var/rootdirs/home/root/mdb.db',
    '/home/root/mdb.db',
    '/data/root/mdb.db',
    '/data/uplink-service/uplink.yaml',
    '/data/uplink-service/config.yaml',
    '/data/radio-gaga/config.yaml',
    '/etc/rescoot/radio-gaga.yml',
    '/home/root/radio-gaga/radio-gaga.yml',
    '/data/settings.toml.preinstall',
    '/data/keycard/master_uids.txt',
    '/data/keycard/authorized_uids.txt',
  ];

  Future<ConfigurationInventory> inspect() async {
    final fixed = _fixedPaths.map(_shellEscape).join(' ');
    final output = await _runCommand('''
for p in $fixed; do
  [ -f "\$p" ] && printf '%s\\n' "\$p"
done
for d in /data/wireguard /etc/wireguard; do
  [ -d "\$d" ] || continue
  find "\$d" -maxdepth 1 -type f -name '*.conf' -print 2>/dev/null
done
true
''');
    final found = output
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final sources = <ConfigurationSource>[];

    void firstFound({
      required ConfigurationCategory category,
      required List<String> candidates,
      required String restorePath,
      required String localName,
      bool rewriteRadioConfig = false,
    }) {
      for (final candidate in candidates) {
        if (!found.contains(candidate)) continue;
        sources.add(
          ConfigurationSource(
            category: category,
            sourcePath: candidate,
            restorePath: restorePath,
            localName: localName,
            rewriteRadioConfig: rewriteRadioConfig,
          ),
        );
        return;
      }
    }

    firstFound(
      category: ConfigurationCategory.identity,
      candidates: const [
        '/var/rootdirs/home/root/scooter-id',
        '/home/root/scooter-id',
        '/data/root/scooter-id',
      ],
      restorePath: '/data/root/scooter-id',
      localName: 'scooter-id',
    );
    firstFound(
      category: ConfigurationCategory.identity,
      candidates: const [
        '/var/rootdirs/home/root/mdb.db',
        '/home/root/mdb.db',
        '/data/root/mdb.db',
      ],
      restorePath: '/data/root/mdb.db',
      localName: 'mdb.db',
    );
    for (final filename in const ['uplink.yaml', 'config.yaml']) {
      final remotePath = '/data/uplink-service/$filename';
      if (!found.contains(remotePath)) continue;
      sources.add(
        ConfigurationSource(
          category: ConfigurationCategory.uplink,
          sourcePath: remotePath,
          restorePath: remotePath,
          localName: filename,
        ),
      );
    }
    firstFound(
      category: ConfigurationCategory.radioGaga,
      candidates: const [
        '/data/radio-gaga/config.yaml',
        '/etc/rescoot/radio-gaga.yml',
        '/home/root/radio-gaga/radio-gaga.yml',
      ],
      restorePath: '/data/radio-gaga/config.yaml',
      localName: 'config.yaml',
      rewriteRadioConfig: true,
    );
    firstFound(
      category: ConfigurationCategory.settings,
      candidates: const ['/data/settings.toml.preinstall'],
      restorePath: '/data/settings.toml',
      localName: 'settings.toml',
    );
    firstFound(
      category: ConfigurationCategory.keycards,
      candidates: const ['/data/keycard/master_uids.txt'],
      restorePath: '/data/keycard/master_uids.txt',
      localName: 'master_uids.txt',
    );
    firstFound(
      category: ConfigurationCategory.keycards,
      candidates: const ['/data/keycard/authorized_uids.txt'],
      restorePath: '/data/keycard/authorized_uids.txt',
      localName: 'authorized_uids.txt',
    );

    final wireGuardByName = <String, String>{};
    for (final prefix in const ['/data/wireguard/', '/etc/wireguard/']) {
      final candidates = found.where((remotePath) {
        if (!remotePath.startsWith(prefix) || !remotePath.endsWith('.conf')) {
          return false;
        }
        return _safeBasename(path.posix.basename(remotePath));
      }).toList()..sort();
      for (final remotePath in candidates) {
        wireGuardByName.putIfAbsent(
          path.posix.basename(remotePath),
          () => remotePath,
        );
      }
    }
    for (final entry in wireGuardByName.entries) {
      sources.add(
        ConfigurationSource(
          category: ConfigurationCategory.wireGuard,
          sourcePath: entry.value,
          restorePath: '/data/wireguard/${entry.key}',
          localName: entry.key,
        ),
      );
    }

    debugPrint(
      'Config: detected categories: '
      '${sources.map((source) => source.category.name).toSet().join(', ')}',
    );
    return ConfigurationInventory(sources);
  }

  Future<ConfigurationBackup> backup({
    required ConfigurationInventory inventory,
    required Set<ConfigurationCategory> selected,
    required String baseDirectory,
    required String runId,
  }) async {
    if (selected.isEmpty) {
      throw ArgumentError.value(selected, 'selected', 'must not be empty');
    }
    final safeRunId = runId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final backupDir = await _createBackupDirectory(
      baseDirectory: baseDirectory,
      safeRunId: safeRunId,
    );

    final manifestFiles = <Map<String, Object?>>[];
    String? scooterIdVin;
    String? databaseVin;

    try {
      for (final source in inventory.sources) {
        if (!selected.contains(source.category)) continue;
        var bytes = await _download(source.sourcePath);
        if (bytes == null) {
          throw StateError(
            'Selected configuration disappeared: ${source.sourcePath}',
          );
        }

        if (source.category == ConfigurationCategory.identity &&
            source.localName == 'scooter-id') {
          scooterIdVin = _extractVin(bytes);
        }
        if (source.category == ConfigurationCategory.identity &&
            source.localName == 'mdb.db') {
          databaseVin = await _readDatabaseVin(source.sourcePath);
        }

        final extraFiles = <_BackupFile>[];
        if (source.category == ConfigurationCategory.radioGaga &&
            source.rewriteRadioConfig) {
          final normalized = await _normalizeRadioConfig(bytes);
          bytes = normalized.config;
          extraFiles.addAll(normalized.extraFiles);
        }

        await _writeBackupFile(
          backupDir: backupDir,
          category: source.category,
          localName: source.localName,
          bytes: bytes,
        );
        manifestFiles.add({
          'category': source.category.name,
          'source': source.sourcePath,
          'restore': source.restorePath,
          'localName': source.localName,
          'bytes': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
        });

        for (final extra in extraFiles) {
          await _writeBackupFile(
            backupDir: backupDir,
            category: source.category,
            localName: extra.localName,
            bytes: extra.bytes,
          );
          manifestFiles.add({
            'category': source.category.name,
            'source': extra.sourcePath,
            'restore': extra.restorePath,
            'localName': extra.localName,
            'bytes': extra.bytes.length,
            'sha256': sha256.convert(extra.bytes).toString(),
          });
        }
      }

      final identity = <String, Object?>{
        'scooterIdVin': scooterIdVin,
        'databaseVin': databaseVin,
        'preferredVin': scooterIdVin ?? databaseVin,
        'disagreement':
            scooterIdVin != null &&
            databaseVin != null &&
            scooterIdVin != databaseVin,
      };
      final manifest = <String, Object?>{
        'schemaVersion': 2,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'runId': runId,
        'categories': selected.map((category) => category.name).toList()
          ..sort(),
        'files': manifestFiles,
        'identity': identity,
      };
      await _writePrivateFile(
        File(path.join(backupDir.path, 'manifest.json')),
        Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
        ),
      );
      await _handBackupOwnershipToUser(backupDir, Directory(baseDirectory));
      debugPrint(
        'Config: backed up ${manifestFiles.length} file(s) to ${backupDir.path}',
      );
      return ConfigurationBackup(
        directoryPath: backupDir.path,
        categories: Set.unmodifiable(selected),
      );
    } catch (error) {
      await _handBackupOwnershipToUser(backupDir, Directory(baseDirectory));
      debugPrint('Config: backup incomplete; retained at ${backupDir.path}');
      throw ConfigurationRestoreException(
        backupDir.path,
        'Configuration backup failed: $error',
      );
    }
  }

  Future<void> restore(ConfigurationBackup backup) async {
    final token = _randomToken();
    var files = const <_RestoreFile>[];
    final commitAttempts = <_RestoreFile>[];
    try {
      files = await _readRestoreFiles(backup);

      // Validate and stage the whole set before replacing any live path.
      for (final file in files) {
        final directory = path.posix.dirname(file.restorePath);
        final temporaryPath = file.temporaryPath(token);
        await _runCommand(
          'mkdir -p ${_shellEscape(directory)} && '
          'rm -f ${_shellEscape(temporaryPath)} && '
          ': > ${_shellEscape(temporaryPath)} && '
          'chmod 600 ${_shellEscape(temporaryPath)}',
        );
        await _upload(file.bytes, temporaryPath);
        await _runCommand('chmod 600 ${_shellEscape(temporaryPath)}');
        final temporaryReadback = await _download(temporaryPath);
        if (temporaryReadback == null ||
            !listEquals(file.bytes, temporaryReadback)) {
          throw StateError(
            'Staged read-back verification failed for ${file.restorePath}',
          );
        }
      }

      for (final file in files) {
        final temporaryPath = file.temporaryPath(token);
        final rollbackPath = file.rollbackPath(token);
        // Record the attempt before the command. If SSH loses the response
        // after the rename, rollback can still infer what happened from the
        // durable temporary and rollback paths.
        commitAttempts.add(file);
        final hadPrevious = (await _runCommand(
          'rm -f ${_shellEscape(rollbackPath)} || exit 1; '
          'had_previous=0; '
          'if [ -e ${_shellEscape(file.restorePath)} ]; then '
          'mv -f ${_shellEscape(file.restorePath)} '
          '${_shellEscape(rollbackPath)} || exit 1; '
          'had_previous=1; '
          'fi; '
          'mv -f ${_shellEscape(temporaryPath)} '
          '${_shellEscape(file.restorePath)} || exit 1; '
          'chmod 600 ${_shellEscape(file.restorePath)} || exit 1; '
          'printf "%s" "\$had_previous"',
        )).trim();
        if (hadPrevious != '0' && hadPrevious != '1') {
          throw StateError(
            'Could not confirm restore commit for ${file.restorePath}',
          );
        }
      }

      await _verifyFiles(files, afterFinalization: false);
      for (final file in files) {
        try {
          await _runCommand(
            'rm -f ${_shellEscape(file.rollbackPath(token))} '
            '${_shellEscape(file.temporaryPath(token))}',
          );
        } catch (_) {}
      }
      debugPrint('Config: restored and verified selected configuration');
    } catch (error) {
      for (final file in commitAttempts.reversed) {
        try {
          final rollbackPath = file.rollbackPath(token);
          final temporaryPath = file.temporaryPath(token);
          await _runCommand(
            'if [ -e ${_shellEscape(rollbackPath)} ]; then '
            'rm -f ${_shellEscape(file.restorePath)}; '
            'mv -f ${_shellEscape(rollbackPath)} '
            '${_shellEscape(file.restorePath)}; '
            'elif [ ! -e ${_shellEscape(temporaryPath)} ]; then '
            'rm -f ${_shellEscape(file.restorePath)}; '
            'fi',
          );
        } catch (_) {}
      }
      for (final file in files) {
        try {
          await _runCommand('rm -f ${_shellEscape(file.temporaryPath(token))}');
        } catch (_) {}
      }
      if (error is ConfigurationRestoreException) rethrow;
      throw ConfigurationRestoreException(
        backup.directoryPath,
        error.toString(),
      );
    }
  }

  /// Verify the final paths against the retained host backup without writing.
  Future<void> verify(
    ConfigurationBackup backup, {
    bool afterFinalization = false,
  }) async {
    try {
      await _verifyFiles(
        await _readRestoreFiles(backup),
        afterFinalization: afterFinalization,
      );
    } catch (error) {
      if (error is ConfigurationRestoreException) rethrow;
      throw ConfigurationRestoreException(
        backup.directoryPath,
        error.toString(),
      );
    }
  }

  Future<void> _verifyFiles(
    List<_RestoreFile> files, {
    required bool afterFinalization,
  }) async {
    for (final file in files) {
      final readback = await _download(file.restorePath);
      final matches =
          readback != null &&
          (afterFinalization && file.category == ConfigurationCategory.settings
              ? _settingsMatchAfterFinalization(file.bytes, readback)
              : afterFinalization &&
                    file.category == ConfigurationCategory.keycards
              ? _keycardEntriesPreserved(file.bytes, readback)
              : listEquals(file.bytes, readback));
      if (!matches) {
        throw StateError(
          'Read-back verification failed for ${file.restorePath}',
        );
      }
    }
  }

  Future<List<_RestoreFile>> _readRestoreFiles(
    ConfigurationBackup backup,
  ) async {
    final backupDir = Directory(backup.directoryPath);
    final manifestFile = File(path.join(backup.directoryPath, 'manifest.json'));
    if (await FileSystemEntity.type(backupDir.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw ConfigurationRestoreException(
        backup.directoryPath,
        'Configuration backup is incomplete.',
      );
    }
    if (await FileSystemEntity.type(manifestFile.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Unsafe configuration backup manifest');
    }
    final manifest = jsonDecode(await manifestFile.readAsString());
    if (manifest is! Map<String, dynamic> || manifest['schemaVersion'] != 2) {
      throw const FormatException('Unsupported configuration backup manifest');
    }
    final manifestCategories = manifest['categories'];
    if (manifestCategories is! List ||
        !backup.categories.every(
          (category) => manifestCategories.contains(category.name),
        )) {
      throw const FormatException('Missing selected backup category');
    }
    final entries = manifest['files'];
    if (entries is! List) {
      throw const FormatException('Missing backup file list');
    }
    final files = <_RestoreFile>[];
    final foundCategories = <ConfigurationCategory>{};
    final restorePaths = <String>{};
    for (final raw in entries) {
      if (raw is! Map) {
        throw const FormatException('Invalid backup file entry');
      }
      final categoryName = raw['category'];
      final localName = raw['localName'];
      final restorePath = raw['restore'];
      final expectedLength = raw['bytes'];
      final expectedDigest = raw['sha256'];
      if (categoryName is! String ||
          localName is! String ||
          restorePath is! String ||
          expectedLength is! int ||
          expectedLength < 0 ||
          expectedDigest is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedDigest) ||
          !_safeBasename(localName)) {
        throw const FormatException('Unsafe backup file entry');
      }
      final category = ConfigurationCategory.values.byName(categoryName);
      if (!_allowedRestorePath(category, restorePath, localName)) {
        throw const FormatException('Unapproved restore path');
      }
      if (!backup.categories.contains(category)) continue;
      if (!restorePaths.add(restorePath)) {
        throw const FormatException('Duplicate backup restore path');
      }
      final categoryDirectory = Directory(
        path.join(backup.directoryPath, category.name),
      );
      if (await FileSystemEntity.type(
            categoryDirectory.path,
            followLinks: false,
          ) !=
          FileSystemEntityType.directory) {
        throw const FormatException('Unsafe backup category directory');
      }
      final localFile = File(path.join(categoryDirectory.path, localName));
      if (!path.isWithin(backupDir.path, localFile.path) ||
          await FileSystemEntity.type(localFile.path, followLinks: false) !=
              FileSystemEntityType.file) {
        throw const FormatException('Unsafe backup file');
      }
      final bytes = Uint8List.fromList(await localFile.readAsBytes());
      if (bytes.length != expectedLength ||
          sha256.convert(bytes).toString() != expectedDigest) {
        throw const FormatException('Backup file integrity check failed');
      }
      foundCategories.add(category);
      files.add(
        _RestoreFile(
          category: category,
          restorePath: restorePath,
          bytes: bytes,
        ),
      );
    }
    if (!foundCategories.containsAll(backup.categories)) {
      throw const FormatException('Selected backup category has no files');
    }
    return files;
  }

  Future<void> deleteBackup(ConfigurationBackup backup) async {
    final type = await FileSystemEntity.type(
      backup.directoryPath,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw StateError('Refusing to delete an unsafe configuration backup');
    }
    await Directory(backup.directoryPath).delete(recursive: true);
    debugPrint('Config: deleted verified backup ${backup.directoryPath}');
  }

  Future<void> _handBackupOwnershipToUser(
    Directory backupDir,
    Directory baseDirectory,
  ) async {
    if (Platform.isWindows || !_looksElevated) return;
    try {
      final statArgs = Platform.isMacOS
          ? ['-f', '%u:%g', baseDirectory.path]
          : ['-c', '%u:%g', baseDirectory.path];
      final result = await Process.run('stat', statArgs);
      final owner = result.stdout.toString().trim();
      if (result.exitCode != 0 ||
          !RegExp(r'^[0-9]+:[0-9]+$').hasMatch(owner) ||
          owner.startsWith('0:')) {
        return;
      }
      await Process.run('chown', ['-R', owner, backupDir.path]);
    } catch (error) {
      debugPrint('Config: could not hand backup ownership to the user: $error');
    }
  }

  bool get _looksElevated {
    final home = Platform.environment['HOME'];
    return Platform.environment['SUDO_USER'] != null ||
        Platform.environment['USER'] == 'root' ||
        home == '/root' ||
        home == '/var/root';
  }

  Future<_NormalizedRadioConfig> _normalizeRadioConfig(Uint8List bytes) async {
    var text = utf8.decode(bytes);
    final extras = <_BackupFile>[];
    try {
      final yaml = loadYaml(text);
      final mqtt = yaml is Map ? yaml['mqtt'] : null;
      final caPath = mqtt is Map ? mqtt['ca_cert'] : null;
      if (caPath is String && caPath.startsWith('/')) {
        final basename = path.posix.basename(caPath);
        if (!_safeBasename(basename) || basename == 'config.yaml') {
          throw StateError('Unsafe radio-gaga CA certificate path');
        }
        final cert = await _download(caPath);
        if (cert == null || cert.isEmpty) {
          throw StateError(
            'Referenced radio-gaga CA certificate is unavailable',
          );
        }
        final target = '/data/radio-gaga/$basename';
        text = text.replaceAll(caPath, target);
        extras.add(
          _BackupFile(
            sourcePath: caPath,
            restorePath: target,
            localName: basename,
            bytes: cert,
          ),
        );
      }
    } on StateError {
      rethrow;
    } catch (error) {
      debugPrint('Config: radio-gaga config could not be normalized: $error');
    }
    return _NormalizedRadioConfig(
      config: Uint8List.fromList(utf8.encode(text)),
      extraFiles: extras,
    );
  }

  Future<Directory> _createBackupDirectory({
    required String baseDirectory,
    required String safeRunId,
  }) async {
    await Directory(baseDirectory).create(recursive: true);
    for (var attempt = 0; attempt < 8; attempt++) {
      final directory = Directory(
        path.join(
          baseDirectory,
          'configuration-backup-$safeRunId-${_randomToken()}',
        ),
      );
      if (await FileSystemEntity.type(directory.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        continue;
      }
      if (Platform.isWindows) {
        try {
          await directory.create();
        } on FileSystemException {
          continue;
        }
        if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw StateError('Unsafe configuration backup directory');
        }
        try {
          await _secureWindowsDirectory(directory);
        } catch (_) {
          try {
            await directory.delete(recursive: true);
          } catch (_) {}
          rethrow;
        }
      } else {
        final result = await Process.run('mkdir', [
          '-m',
          '700',
          directory.path,
        ]);
        if (result.exitCode != 0) continue;
        if (await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw StateError('Unsafe configuration backup directory');
        }
      }
      return directory;
    }
    throw StateError('Could not create a private configuration backup');
  }

  Future<void> _secureWindowsDirectory(Directory directory) async {
    final identity = await Process.run('whoami', [
      '/user',
      '/fo',
      'csv',
      '/nh',
    ]);
    final sid = RegExp(
      r'S-1-[0-9-]+',
    ).firstMatch(identity.stdout.toString())?.group(0);
    if (identity.exitCode != 0 || sid == null) {
      throw StateError('Could not determine the Windows backup owner');
    }
    final acl = await Process.run('icacls', [
      directory.path,
      '/inheritance:r',
      '/grant:r',
      '*$sid:(OI)(CI)F',
    ]);
    if (acl.exitCode != 0) {
      throw StateError('Could not secure the Windows configuration backup');
    }
  }

  Future<void> _writeBackupFile({
    required Directory backupDir,
    required ConfigurationCategory category,
    required String localName,
    required Uint8List bytes,
  }) async {
    if (!_safeBasename(localName)) throw StateError('Unsafe backup filename');
    final categoryDir = Directory(path.join(backupDir.path, category.name));
    final entityType = await FileSystemEntity.type(
      categoryDir.path,
      followLinks: false,
    );
    if (entityType == FileSystemEntityType.notFound) {
      await categoryDir.create();
      if (!Platform.isWindows) {
        await _runChecked('chmod', ['700', categoryDir.path]);
      }
    } else if (entityType != FileSystemEntityType.directory) {
      throw StateError('Unsafe backup category directory');
    }
    await _writePrivateFile(
      File(path.join(categoryDir.path, localName)),
      bytes,
    );
  }

  Future<void> _writePrivateFile(File file, Uint8List bytes) async {
    await file.create(exclusive: true);
    final output = await file.open(mode: FileMode.writeOnly);
    try {
      await output.writeFrom(bytes);
      await output.flush();
    } finally {
      await output.close();
    }
    if (!Platform.isWindows) {
      await _runChecked('chmod', ['600', file.path]);
    }
  }

  Future<void> _runChecked(String executable, List<String> arguments) async {
    final result = await Process.run(executable, arguments);
    if (result.exitCode != 0) {
      throw StateError('$executable failed while securing the backup');
    }
  }

  static bool _settingsMatchAfterFinalization(
    Uint8List expectedBytes,
    Uint8List actualBytes,
  ) {
    final expected = _parseSettings(expectedBytes);
    final actual = _parseSettings(actualBytes);
    if (expected == null || actual == null) return false;
    for (final key in const {
      'dashboard.language',
      'updates.mdb.channel',
      'updates.dbc.channel',
      'scooter.usb0-policy',
    }) {
      expected.remove(key);
      actual.remove(key);
    }
    return mapEquals(expected, actual);
  }

  // settings-service emits scalar Redis values under plain nested tables.
  // Reject TOML forms outside that contract rather than comparing them loosely.
  static Map<String, String>? _parseSettings(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return null;
    }
    if (text.trim().isEmpty) return null;
    var section = '';
    final values = <String, String>{};
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = _withoutTomlComment(rawLine).trim();
      if (line.isEmpty) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        if (line.startsWith('[[')) return null;
        section = line.substring(1, line.length - 1).trim();
        if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(section)) return null;
        continue;
      }
      final separator = _tomlAssignmentSeparator(line);
      if (separator <= 0) return null;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(key) || value.isEmpty) {
        return null;
      }
      final fullKey = section.isEmpty ? key : '$section.$key';
      if (values.containsKey(fullKey)) return null;
      final normalized = _normalizeTomlValue(value);
      if (normalized == null) return null;
      values[fullKey] = normalized;
    }
    return values.isEmpty ? null : values;
  }

  static String _withoutTomlComment(String line) {
    var quote = '';
    var escaped = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (quote == '"' && char == '\\') {
        escaped = true;
        continue;
      }
      if (char == '"' || char == "'") {
        if (quote.isEmpty) {
          quote = char;
        } else if (quote == char) {
          quote = '';
        }
      } else if (char == '#' && quote.isEmpty) {
        return line.substring(0, index);
      }
    }
    return line;
  }

  static int _tomlAssignmentSeparator(String line) {
    var quote = '';
    var escaped = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (quote == '"' && char == '\\') {
        escaped = true;
        continue;
      }
      if (char == '"' || char == "'") {
        if (quote.isEmpty) {
          quote = char;
        } else if (quote == char) {
          quote = '';
        }
      } else if (char == '=' && quote.isEmpty) {
        return index;
      }
    }
    return -1;
  }

  static String? _normalizeTomlValue(String value) {
    if (value.startsWith('"')) {
      if (value.length < 2 || !value.endsWith('"')) return null;
      try {
        final decoded = jsonDecode(value);
        return decoded is String ? 'string:$decoded' : null;
      } catch (_) {
        return null;
      }
    }
    if (value.startsWith("'")) {
      if (value.length < 2 || !value.endsWith("'")) return null;
      return 'string:${value.substring(1, value.length - 1)}';
    }
    if ((value.startsWith('[') && !value.endsWith(']')) ||
        (value.startsWith('{') && !value.endsWith('}')) ||
        value.contains('"') ||
        value.contains("'")) {
      return null;
    }
    return value;
  }

  static bool _keycardEntriesPreserved(
    Uint8List expectedBytes,
    Uint8List actualBytes,
  ) {
    Set<String>? entries(Uint8List bytes) {
      try {
        return const LineSplitter()
            .convert(utf8.decode(bytes))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toSet();
      } on FormatException {
        return null;
      }
    }

    final expected = entries(expectedBytes);
    final actual = entries(actualBytes);
    return expected != null && actual != null && actual.containsAll(expected);
  }

  static String _randomToken() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<String?> _readDatabaseVin(String databasePath) async {
    try {
      final tables =
          (await _runCommand(
                'sqlite3 ${_shellEscape(databasePath)} ".tables" 2>/dev/null || true',
              ))
              .split(RegExp(r'\s+'))
              .where((name) => RegExp(r'^[A-Za-z0-9_]+$').hasMatch(name))
              .toList();
      for (final table in tables) {
        final columns =
            (await _runCommand(
                  'sqlite3 ${_shellEscape(databasePath)} '
                  '${_shellEscape("select name from pragma_table_info('$table');")} '
                  '2>/dev/null || true',
                ))
                .split('\n')
                .map((name) => name.trim())
                .where((name) => RegExp(r'^[A-Za-z0-9_]+$').hasMatch(name))
                .toList();
        final vinColumn = columns.where(
          (name) => const {
            'vin',
            'vehicle_vin',
            'vehicle_identification_number',
          }.contains(name.toLowerCase()),
        );
        for (final column in vinColumn) {
          final value = await _runCommand(
            'sqlite3 ${_shellEscape(databasePath)} '
            '${_shellEscape('select "$column" from "$table" where "$column" is not null limit 1;')} '
            '2>/dev/null || true',
          );
          final vin = _extractVin(Uint8List.fromList(utf8.encode(value)));
          if (vin != null) return vin;
        }
        final key = columns.where((name) => name.toLowerCase() == 'key');
        final value = columns.where((name) => name.toLowerCase() == 'value');
        if (key.isNotEmpty && value.isNotEmpty) {
          final output = await _runCommand(
            'sqlite3 ${_shellEscape(databasePath)} '
            '${_shellEscape('select "${value.first}" from "$table" where lower("${key.first}") in (\'vin\', \'vehicle_vin\') limit 1;')} '
            '2>/dev/null || true',
          );
          final vin = _extractVin(Uint8List.fromList(utf8.encode(output)));
          if (vin != null) return vin;
        }
      }
    } catch (_) {
      // The database itself is still preserved. The manifest records null
      // rather than turning optional identity metadata into a backup failure.
    }
    return null;
  }

  static String? _extractVin(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true).toUpperCase();
    return RegExp(
      r'(?<![A-Z0-9])[A-HJ-NPR-Z0-9]{17}(?![A-Z0-9])',
    ).firstMatch(text)?.group(0);
  }

  static bool _allowedRestorePath(
    ConfigurationCategory category,
    String restorePath,
    String localName,
  ) {
    if (path.posix.normalize(restorePath) != restorePath) return false;
    return switch (category) {
      ConfigurationCategory.identity =>
        restorePath == '/data/root/scooter-id' ||
            restorePath == '/data/root/mdb.db',
      ConfigurationCategory.wireGuard =>
        restorePath == '/data/wireguard/$localName' &&
            localName.endsWith('.conf'),
      ConfigurationCategory.uplink =>
        restorePath == '/data/uplink-service/$localName' &&
            (localName == 'uplink.yaml' || localName == 'config.yaml'),
      ConfigurationCategory.radioGaga =>
        restorePath == '/data/radio-gaga/$localName',
      ConfigurationCategory.settings => restorePath == '/data/settings.toml',
      ConfigurationCategory.keycards =>
        restorePath == '/data/keycard/master_uids.txt' ||
            restorePath == '/data/keycard/authorized_uids.txt',
    };
  }

  static bool _safeBasename(String value) =>
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value) &&
      value != '.' &&
      value != '..';

  static String _shellEscape(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";
}

class _RestoreFile {
  const _RestoreFile({
    required this.category,
    required this.restorePath,
    required this.bytes,
  });

  final ConfigurationCategory category;
  final String restorePath;
  final Uint8List bytes;

  String temporaryPath(String token) =>
      '$restorePath.librescoot-installer-tmp-$token';

  String rollbackPath(String token) =>
      '$restorePath.librescoot-installer-old-$token';
}

class _BackupFile {
  const _BackupFile({
    required this.sourcePath,
    required this.restorePath,
    required this.localName,
    required this.bytes,
  });

  final String sourcePath;
  final String restorePath;
  final String localName;
  final Uint8List bytes;
}

class _NormalizedRadioConfig {
  const _NormalizedRadioConfig({
    required this.config,
    required this.extraFiles,
  });

  final Uint8List config;
  final List<_BackupFile> extraFiles;
}
