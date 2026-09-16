import 'dart:convert';
import 'dart:io';
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
    final backupDir = Directory(
      path.join(baseDirectory, 'configuration-backup-$safeRunId'),
    );
    await backupDir.create(recursive: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['700', backupDir.path]);
    }

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
        'schemaVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'runId': runId,
        'categories': selected.map((category) => category.name).toList()
          ..sort(),
        'files': manifestFiles,
        'identity': identity,
      };
      await File(path.join(backupDir.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
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
    try {
      final files = await _readRestoreFiles(backup);
      for (final file in files) {
        final directory = path.posix.dirname(file.restorePath);
        final temporaryPath = '${file.restorePath}.librescoot-installer-tmp';
        try {
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
              'Read-back verification failed for ${file.restorePath}',
            );
          }
          await _runCommand(
            'mv -f ${_shellEscape(temporaryPath)} '
            '${_shellEscape(file.restorePath)}',
          );
        } catch (_) {
          try {
            await _runCommand('rm -f ${_shellEscape(temporaryPath)}');
          } catch (_) {}
          rethrow;
        }
      }
      await verify(backup);
      debugPrint('Config: restored and verified selected configuration');
    } catch (error) {
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
    bool allowSettingsChanges = false,
  }) async {
    try {
      for (final file in await _readRestoreFiles(backup)) {
        final readback = await _download(file.restorePath);
        final settingsMayHaveFinishChoices =
            allowSettingsChanges && file.restorePath == '/data/settings.toml';
        if (readback == null ||
            (!settingsMayHaveFinishChoices &&
                !listEquals(file.bytes, readback))) {
          throw StateError(
            'Read-back verification failed for ${file.restorePath}',
          );
        }
      }
    } catch (error) {
      if (error is ConfigurationRestoreException) rethrow;
      throw ConfigurationRestoreException(
        backup.directoryPath,
        error.toString(),
      );
    }
  }

  Future<List<_RestoreFile>> _readRestoreFiles(
    ConfigurationBackup backup,
  ) async {
    final backupDir = Directory(backup.directoryPath);
    final manifestFile = File(path.join(backup.directoryPath, 'manifest.json'));
    if (!await backupDir.exists() || !await manifestFile.exists()) {
      throw ConfigurationRestoreException(
        backup.directoryPath,
        'Configuration backup is incomplete.',
      );
    }
    final manifest = jsonDecode(await manifestFile.readAsString());
    if (manifest is! Map<String, dynamic> || manifest['schemaVersion'] != 1) {
      throw const FormatException('Unsupported configuration backup manifest');
    }
    final entries = manifest['files'];
    if (entries is! List) {
      throw const FormatException('Missing backup file list');
    }
    final files = <_RestoreFile>[];
    for (final raw in entries) {
      if (raw is! Map) {
        throw const FormatException('Invalid backup file entry');
      }
      final categoryName = raw['category'];
      final localName = raw['localName'];
      final restorePath = raw['restore'];
      if (categoryName is! String ||
          localName is! String ||
          restorePath is! String ||
          !_safeBasename(localName)) {
        throw const FormatException('Unsafe backup file entry');
      }
      final category = ConfigurationCategory.values.byName(categoryName);
      if (!_allowedRestorePath(category, restorePath, localName)) {
        throw const FormatException('Unapproved restore path');
      }
      if (!backup.categories.contains(category)) continue;
      final localFile = File(
        path.join(backup.directoryPath, category.name, localName),
      );
      files.add(
        _RestoreFile(
          restorePath: restorePath,
          bytes: Uint8List.fromList(await localFile.readAsBytes()),
        ),
      );
    }
    return files;
  }

  Future<void> deleteBackup(ConfigurationBackup backup) async {
    final directory = Directory(backup.directoryPath);
    if (await directory.exists()) await directory.delete(recursive: true);
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

  Future<void> _writeBackupFile({
    required Directory backupDir,
    required ConfigurationCategory category,
    required String localName,
    required Uint8List bytes,
  }) async {
    if (!_safeBasename(localName)) throw StateError('Unsafe backup filename');
    final categoryDir = Directory(path.join(backupDir.path, category.name));
    await categoryDir.create(recursive: true);
    final file = File(path.join(categoryDir.path, localName));
    await file.writeAsBytes(bytes, flush: true);
    if (!Platform.isWindows) await Process.run('chmod', ['600', file.path]);
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
  const _RestoreFile({required this.restorePath, required this.bytes});

  final String restorePath;
  final Uint8List bytes;
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
