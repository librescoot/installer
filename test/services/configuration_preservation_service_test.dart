import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/configuration_preservation.dart';
import 'package:librescoot_installer/services/configuration_preservation_service.dart';
import 'package:path/path.dart' as path;

Map<String, Object> manifestEntry({
  required String category,
  required String restorePath,
  required String localName,
  required Uint8List bytes,
}) => {
  'category': category,
  'source': restorePath,
  'restore': restorePath,
  'localName': localName,
  'bytes': bytes.length,
  'sha256': sha256.convert(bytes).toString(),
};

void writeManifest(
  Directory backupDir, {
  required List<String> categories,
  required List<Map<String, Object>> files,
}) {
  File(path.join(backupDir.path, 'manifest.json')).writeAsStringSync(
    jsonEncode({'schemaVersion': 2, 'categories': categories, 'files': files}),
  );
}

ConfigurationBackup createBackupFixture(
  Directory root, {
  required Map<ConfigurationCategory, Map<String, Uint8List>> files,
}) {
  final entries = <Map<String, Object>>[];
  for (final categoryEntry in files.entries) {
    final categoryDir = Directory(path.join(root.path, categoryEntry.key.name))
      ..createSync(recursive: true);
    for (final fileEntry in categoryEntry.value.entries) {
      final restorePath = switch (categoryEntry.key) {
        ConfigurationCategory.settings => '/data/settings.toml',
        ConfigurationCategory.keycards => '/data/keycard/${fileEntry.key}',
        ConfigurationCategory.uplink => '/data/uplink-service/${fileEntry.key}',
        _ => throw UnsupportedError('test fixture category'),
      };
      File(
        path.join(categoryDir.path, fileEntry.key),
      ).writeAsBytesSync(fileEntry.value);
      entries.add(
        manifestEntry(
          category: categoryEntry.key.name,
          restorePath: restorePath,
          localName: fileEntry.key,
          bytes: fileEntry.value,
        ),
      );
    }
  }
  writeManifest(
    root,
    categories: files.keys.map((category) => category.name).toList(),
    files: entries,
  );
  return ConfigurationBackup(
    directoryPath: root.path,
    categories: files.keys.toSet(),
  );
}

void main() {
  test(
    'inspection keeps approved paths and prefers the stock identity source',
    () async {
      final service = ConfigurationPreservationService.withTransport(
        runCommand: (_) async => '''
/var/rootdirs/home/root/scooter-id
/data/root/scooter-id
/var/rootdirs/home/root/mdb.db
/data/settings.toml.preinstall
/data/uplink-service/uplink.yaml
/data/uplink-service/config.yaml
/data/wireguard/wg0.conf
/etc/wireguard/wg0.conf
/data/wireguard/bad name.conf
/etc/passwd
''',
        download: (_) async => null,
        upload: (_, __) async {},
      );

      final inventory = await service.inspect();

      expect(inventory.categories, {
        ConfigurationCategory.identity,
        ConfigurationCategory.settings,
        ConfigurationCategory.uplink,
        ConfigurationCategory.wireGuard,
      });
      final identity = inventory.sources
          .where((source) => source.category == ConfigurationCategory.identity)
          .toList();
      expect(identity.map((source) => source.sourcePath), [
        '/var/rootdirs/home/root/scooter-id',
        '/var/rootdirs/home/root/mdb.db',
      ]);
      expect(
        inventory.sources
            .where(
              (source) => source.category == ConfigurationCategory.wireGuard,
            )
            .single
            .sourcePath,
        '/data/wireguard/wg0.conf',
      );
      expect(
        inventory.sources
            .where((source) => source.category == ConfigurationCategory.uplink)
            .map((source) => source.localName),
        ['uplink.yaml', 'config.yaml'],
      );
    },
  );

  test(
    'does not preserve installer-created settings without a snapshot',
    () async {
      final service = ConfigurationPreservationService.withTransport(
        runCommand: (_) async => '/data/settings.toml\n',
        download: (_) async => null,
        upload: (_, __) async {},
      );

      final inventory = await service.inspect();

      expect(
        inventory.categories,
        isNot(contains(ConfigurationCategory.settings)),
      );
    },
  );

  test(
    'backup writes only selected categories and records both VIN sources',
    () async {
      final temp = await Directory.systemTemp.createTemp('config-backup-test-');
      addTearDown(() => temp.delete(recursive: true));
      final files = <String, Uint8List>{
        '/root/scooter-id': Uint8List.fromList(
          utf8.encode('WUNU1234567890123\n'),
        ),
        '/root/mdb.db': Uint8List.fromList([1, 2, 3]),
        '/data/settings.toml': Uint8List.fromList(
          utf8.encode('language = "de"'),
        ),
      };
      final service = ConfigurationPreservationService.withTransport(
        runCommand: (command) async {
          if (command.contains('".tables"')) return 'identity';
          if (command.contains('pragma_table_info')) return 'vin\n';
          if (command.contains('select "vin"')) return 'WUNU7654321098765\n';
          return '';
        },
        download: (remotePath) async => files[remotePath],
        upload: (_, __) async {},
      );
      final inventory = ConfigurationInventory([
        const ConfigurationSource(
          category: ConfigurationCategory.identity,
          sourcePath: '/root/scooter-id',
          restorePath: '/data/root/scooter-id',
          localName: 'scooter-id',
        ),
        const ConfigurationSource(
          category: ConfigurationCategory.identity,
          sourcePath: '/root/mdb.db',
          restorePath: '/data/root/mdb.db',
          localName: 'mdb.db',
        ),
        const ConfigurationSource(
          category: ConfigurationCategory.settings,
          sourcePath: '/data/settings.toml',
          restorePath: '/data/settings.toml',
          localName: 'settings.toml',
        ),
      ]);

      final backup = await service.backup(
        inventory: inventory,
        selected: {ConfigurationCategory.identity},
        baseDirectory: temp.path,
        runId: 'run-1',
      );
      final manifest =
          jsonDecode(
                await File(
                  path.join(backup.directoryPath, 'manifest.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final identity = manifest['identity'] as Map<String, dynamic>;
      final manifestFiles = manifest['files'] as List<dynamic>;

      expect(manifest['schemaVersion'], 2);
      expect(manifestFiles, everyElement(contains('sha256')));
      expect(
        path.basename(backup.directoryPath),
        matches(RegExp(r'^configuration-backup-run-1-[a-f0-9]{32}$')),
      );
      if (!Platform.isWindows) {
        expect(FileStat.statSync(backup.directoryPath).mode & 0x1ff, 0x1c0);
        expect(
          FileStat.statSync(
                path.join(backup.directoryPath, 'manifest.json'),
              ).mode &
              0x1ff,
          0x180,
        );
      }
      expect(identity['scooterIdVin'], 'WUNU1234567890123');
      expect(identity['databaseVin'], 'WUNU7654321098765');
      expect(identity['preferredVin'], 'WUNU1234567890123');
      expect(identity['disagreement'], isTrue);
      expect(
        File(
          path.join(backup.directoryPath, 'settings', 'settings.toml'),
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          path.join(backup.directoryPath, 'identity', 'mdb.db'),
        ).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'radio-gaga backup carries and rewrites its referenced CA certificate',
    () async {
      final temp = await Directory.systemTemp.createTemp('config-radio-test-');
      addTearDown(() => temp.delete(recursive: true));
      final service = ConfigurationPreservationService.withTransport(
        runCommand: (_) async => '',
        download: (remotePath) async => switch (remotePath) {
          '/etc/rescoot/radio-gaga.yml' => Uint8List.fromList(
            utf8.encode('mqtt:\n  ca_cert: /etc/ssl/private/cloud-ca.pem\n'),
          ),
          '/etc/ssl/private/cloud-ca.pem' => Uint8List.fromList([4, 5, 6]),
          _ => null,
        },
        upload: (_, __) async {},
      );
      const inventory = ConfigurationInventory([
        ConfigurationSource(
          category: ConfigurationCategory.radioGaga,
          sourcePath: '/etc/rescoot/radio-gaga.yml',
          restorePath: '/data/radio-gaga/config.yaml',
          localName: 'config.yaml',
          rewriteRadioConfig: true,
        ),
      ]);

      final backup = await service.backup(
        inventory: inventory,
        selected: {ConfigurationCategory.radioGaga},
        baseDirectory: temp.path,
        runId: 'run-radio',
      );
      final config = await File(
        path.join(backup.directoryPath, 'radioGaga', 'config.yaml'),
      ).readAsString();

      expect(config, contains('/data/radio-gaga/cloud-ca.pem'));
      expect(
        File(
          path.join(backup.directoryPath, 'radioGaga', 'cloud-ca.pem'),
        ).readAsBytesSync(),
        [4, 5, 6],
      );
    },
  );

  test(
    'radio-gaga backup fails when its referenced CA is unavailable',
    () async {
      final temp = await Directory.systemTemp.createTemp('config-radio-fail-');
      addTearDown(() => temp.delete(recursive: true));
      final service = ConfigurationPreservationService.withTransport(
        runCommand: (_) async => '',
        download: (remotePath) async => remotePath.endsWith('radio-gaga.yml')
            ? Uint8List.fromList(
                utf8.encode('mqtt:\n  ca_cert: /etc/ssl/private/missing.pem\n'),
              )
            : null,
        upload: (_, __) async {},
      );
      const inventory = ConfigurationInventory([
        ConfigurationSource(
          category: ConfigurationCategory.radioGaga,
          sourcePath: '/etc/rescoot/radio-gaga.yml',
          restorePath: '/data/radio-gaga/config.yaml',
          localName: 'config.yaml',
          rewriteRadioConfig: true,
        ),
      ]);

      await expectLater(
        service.backup(
          inventory: inventory,
          selected: {ConfigurationCategory.radioGaga},
          baseDirectory: temp.path,
          runId: 'run-radio-fail',
        ),
        throwsA(isA<ConfigurationRestoreException>()),
      );
    },
  );

  test('failed backup is retained and reports its path', () async {
    final temp = await Directory.systemTemp.createTemp('config-backup-fail-');
    addTearDown(() => temp.delete(recursive: true));
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (_) async => '',
      download: (_) async => null,
      upload: (_, __) async {},
    );
    const inventory = ConfigurationInventory([
      ConfigurationSource(
        category: ConfigurationCategory.settings,
        sourcePath: '/data/settings.toml',
        restorePath: '/data/settings.toml',
        localName: 'settings.toml',
      ),
    ]);

    try {
      await service.backup(
        inventory: inventory,
        selected: {ConfigurationCategory.settings},
        baseDirectory: temp.path,
        runId: 'run-failed',
      );
      fail('backup should fail when the selected source disappears');
    } on ConfigurationRestoreException catch (error) {
      expect(error.backupPath, contains('configuration-backup-run-failed'));
      expect(Directory(error.backupPath).existsSync(), isTrue);
    }
  });

  test('restore uploads every selected file and verifies readback', () async {
    final temp = await Directory.systemTemp.createTemp('config-restore-test-');
    addTearDown(() => temp.delete(recursive: true));
    final backupDir = Directory(path.join(temp.path, 'backup'))
      ..createSync(recursive: true);
    final categoryDir = Directory(path.join(backupDir.path, 'wireGuard'))
      ..createSync();
    final expected = Uint8List.fromList(
      utf8.encode('[Interface]\nPrivateKey=x\n'),
    );
    File(path.join(categoryDir.path, 'wg0.conf')).writeAsBytesSync(expected);
    writeManifest(
      backupDir,
      categories: ['wireGuard'],
      files: [
        manifestEntry(
          category: 'wireGuard',
          restorePath: '/data/wireguard/wg0.conf',
          localName: 'wg0.conf',
          bytes: expected,
        ),
      ],
    );
    final remote = <String, Uint8List>{};
    final commands = <String>[];
    final events = <String>[];
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (command) async {
        commands.add(command);
        events.add('command:$command');
        final commit = RegExp(
          r"mv -f '([^']+)' '([^']+)' \|\| exit 1; chmod 600",
        ).firstMatch(command);
        if (commit != null) {
          final destination = commit.group(2)!;
          final hadPrevious = remote.containsKey(destination);
          remote[destination] = remote.remove(commit.group(1)!)!;
          return hadPrevious ? '1' : '0';
        }
        return '';
      },
      download: (remotePath) async => remote[remotePath],
      upload: (bytes, remotePath) async {
        events.add('upload:$remotePath');
        remote[remotePath] = bytes;
      },
    );

    await service.restore(
      ConfigurationBackup(
        directoryPath: backupDir.path,
        categories: const {ConfigurationCategory.wireGuard},
      ),
    );

    expect(remote['/data/wireguard/wg0.conf'], expected);
    expect(commands.any((command) => command.contains('chmod 600')), isTrue);
    final prepare = events.indexWhere(
      (event) => event.contains(': >') && event.contains('chmod 600'),
    );
    final upload = events.indexWhere((event) => event.startsWith('upload:'));
    final rename = events.indexWhere(
      (event) => event.contains('had_previous=0'),
    );
    expect(prepare, greaterThanOrEqualTo(0));
    expect(upload, greaterThan(prepare));
    expect(rename, greaterThan(upload));
  });

  test('restore failure retains and reports the backup path', () async {
    final temp = await Directory.systemTemp.createTemp('config-restore-fail-');
    addTearDown(() => temp.delete(recursive: true));
    final backupDir = Directory(path.join(temp.path, 'backup'))
      ..createSync(recursive: true);
    final unsafe = Uint8List.fromList(utf8.encode('x'));
    writeManifest(
      backupDir,
      categories: ['settings'],
      files: [
        manifestEntry(
          category: 'settings',
          restorePath: '/etc/passwd',
          localName: 'settings.toml',
          bytes: unsafe,
        ),
      ],
    );
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (_) async => '',
      download: (_) async => null,
      upload: (_, __) async {},
    );

    await expectLater(
      service.restore(
        ConfigurationBackup(
          directoryPath: backupDir.path,
          categories: const {ConfigurationCategory.settings},
        ),
      ),
      throwsA(
        isA<ConfigurationRestoreException>().having(
          (error) => error.backupPath,
          'backupPath',
          backupDir.path,
        ),
      ),
    );
    expect(backupDir.existsSync(), isTrue);
  });

  test('tampered host backup is rejected before any remote write', () async {
    final temp = await Directory.systemTemp.createTemp('config-tamper-test-');
    addTearDown(() => temp.delete(recursive: true));
    final backupDir = Directory(path.join(temp.path, 'backup'))..createSync();
    final original = Uint8List.fromList(
      utf8.encode('[dashboard]\nlanguage = "de"\n'),
    );
    final backup = createBackupFixture(
      backupDir,
      files: {
        ConfigurationCategory.settings: {'settings.toml': original},
      },
    );
    File(
      path.join(backupDir.path, 'settings', 'settings.toml'),
    ).writeAsStringSync('truncated');
    var uploads = 0;
    var commands = 0;
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (_) async {
        commands++;
        return '';
      },
      download: (_) async => null,
      upload: (_, __) async => uploads++,
    );

    await expectLater(
      service.restore(backup),
      throwsA(isA<ConfigurationRestoreException>()),
    );

    expect(uploads, 0);
    expect(commands, 0);
  });

  test('backup category symlinks are rejected', () async {
    if (Platform.isWindows) return;
    final temp = await Directory.systemTemp.createTemp('config-link-test-');
    addTearDown(() => temp.delete(recursive: true));
    final backupDir = Directory(path.join(temp.path, 'backup'))..createSync();
    final outside = Directory(path.join(temp.path, 'outside'))..createSync();
    final bytes = Uint8List.fromList(
      utf8.encode('[dashboard]\nlanguage = "de"\n'),
    );
    File(path.join(outside.path, 'settings.toml')).writeAsBytesSync(bytes);
    Link(path.join(backupDir.path, 'settings')).createSync(outside.path);
    writeManifest(
      backupDir,
      categories: ['settings'],
      files: [
        manifestEntry(
          category: 'settings',
          restorePath: '/data/settings.toml',
          localName: 'settings.toml',
          bytes: bytes,
        ),
      ],
    );
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (_) async => '',
      download: (_) async => null,
      upload: (_, __) async {},
    );

    await expectLater(
      service.verify(
        ConfigurationBackup(
          directoryPath: backupDir.path,
          categories: const {ConfigurationCategory.settings},
        ),
      ),
      throwsA(isA<ConfigurationRestoreException>()),
    );
  });

  test('staging failure leaves every live destination untouched', () async {
    final temp = await Directory.systemTemp.createTemp('config-stage-test-');
    addTearDown(() => temp.delete(recursive: true));
    final backupDir = Directory(path.join(temp.path, 'backup'))..createSync();
    final first = Uint8List.fromList(utf8.encode('uplink: new\n'));
    final second = Uint8List.fromList(utf8.encode('modem: new\n'));
    final backup = createBackupFixture(
      backupDir,
      files: {
        ConfigurationCategory.uplink: {
          'uplink.yaml': first,
          'config.yaml': second,
        },
      },
    );
    final oldFirst = Uint8List.fromList(utf8.encode('uplink: old\n'));
    final oldSecond = Uint8List.fromList(utf8.encode('modem: old\n'));
    final remote = <String, Uint8List>{
      '/data/uplink-service/uplink.yaml': oldFirst,
      '/data/uplink-service/config.yaml': oldSecond,
    };
    final commands = <String>[];
    var uploadCount = 0;
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (command) async {
        commands.add(command);
        return '';
      },
      download: (remotePath) async => remote[remotePath],
      upload: (bytes, remotePath) async {
        uploadCount++;
        remote[remotePath] = uploadCount == 2
            ? Uint8List.fromList([0])
            : Uint8List.fromList(bytes);
      },
    );

    await expectLater(
      service.restore(backup),
      throwsA(isA<ConfigurationRestoreException>()),
    );

    expect(remote['/data/uplink-service/uplink.yaml'], oldFirst);
    expect(remote['/data/uplink-service/config.yaml'], oldSecond);
    expect(
      commands.where((command) => command.contains('had_previous=0')),
      isEmpty,
    );
  });

  test('commit failure rolls already replaced files back', () async {
    final temp = await Directory.systemTemp.createTemp('config-commit-test-');
    addTearDown(() => temp.delete(recursive: true));
    final backupDir = Directory(path.join(temp.path, 'backup'))..createSync();
    final first = Uint8List.fromList(utf8.encode('uplink: new\n'));
    final second = Uint8List.fromList(utf8.encode('modem: new\n'));
    final backup = createBackupFixture(
      backupDir,
      files: {
        ConfigurationCategory.uplink: {
          'uplink.yaml': first,
          'config.yaml': second,
        },
      },
    );
    final oldFirst = Uint8List.fromList(utf8.encode('uplink: old\n'));
    final oldSecond = Uint8List.fromList(utf8.encode('modem: old\n'));
    final remote = <String, Uint8List>{
      '/data/uplink-service/uplink.yaml': oldFirst,
      '/data/uplink-service/config.yaml': oldSecond,
    };
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (command) async {
        final commit = RegExp(
          r"mv -f '([^']+)' '([^']+)' \|\| exit 1; chmod 600",
        ).firstMatch(command);
        if (commit != null) {
          final destination = commit.group(2)!;
          if (destination.endsWith('/config.yaml')) {
            throw StateError('second commit failed');
          }
          final rollback = RegExp(
            r"rm -f '([^']+)' \|\| exit 1; had_previous",
          ).firstMatch(command)!.group(1)!;
          remote[rollback] = remote.remove(destination)!;
          remote[destination] = remote.remove(commit.group(1)!)!;
          return '1';
        }
        final undo = RegExp(
          r"if \[ -e '([^']+)' \]; then rm -f '([^']+)'; mv -f '([^']+)' '([^']+)';",
        ).firstMatch(command);
        if (undo != null) {
          final rollback = undo.group(1)!;
          final destination = undo.group(2)!;
          if (remote.containsKey(rollback)) {
            remote.remove(destination);
            remote[destination] = remote.remove(rollback)!;
          }
        }
        return '';
      },
      download: (remotePath) async => remote[remotePath],
      upload: (bytes, remotePath) async {
        remote[remotePath] = Uint8List.fromList(bytes);
      },
    );

    await expectLater(
      service.restore(backup),
      throwsA(isA<ConfigurationRestoreException>()),
    );

    expect(remote['/data/uplink-service/uplink.yaml'], oldFirst);
    expect(remote['/data/uplink-service/config.yaml'], oldSecond);
  });

  test('ambiguous completed commits are rolled back', () async {
    for (final scenario in [
      (name: 'malformed output', previous: true, throwAfterCommit: false),
      (name: 'lost response', previous: false, throwAfterCommit: true),
    ]) {
      final temp = await Directory.systemTemp.createTemp(
        'config-ambiguous-commit-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final backupDir = Directory(path.join(temp.path, 'backup'))..createSync();
      final replacement = Uint8List.fromList(utf8.encode('uplink: new\n'));
      final original = Uint8List.fromList(utf8.encode('uplink: old\n'));
      final backup = createBackupFixture(
        backupDir,
        files: {
          ConfigurationCategory.uplink: {'uplink.yaml': replacement},
        },
      );
      final destination = '/data/uplink-service/uplink.yaml';
      final remote = <String, Uint8List>{
        if (scenario.previous) destination: original,
      };
      final service = ConfigurationPreservationService.withTransport(
        runCommand: (command) async {
          final commit = RegExp(
            r"rm -f '([^']+)' \|\| exit 1; had_previous=0;.*mv -f '([^']+)' '([^']+)' \|\| exit 1; chmod 600",
          ).firstMatch(command);
          if (commit != null) {
            final rollback = commit.group(1)!;
            final temporary = commit.group(2)!;
            final target = commit.group(3)!;
            final previous = remote.remove(target);
            if (previous != null) remote[rollback] = previous;
            remote[target] = remote.remove(temporary)!;
            if (scenario.throwAfterCommit) {
              throw StateError('response lost after commit');
            }
            return 'unexpected output';
          }
          final undo = RegExp(
            r"if \[ -e '([^']+)' \]; then rm -f '([^']+)'; mv -f '([^']+)' '([^']+)'; elif \[ ! -e '([^']+)' \]; then rm -f '([^']+)'; fi",
          ).firstMatch(command);
          if (undo != null) {
            final rollback = undo.group(1)!;
            final target = undo.group(2)!;
            final temporary = undo.group(5)!;
            if (remote.containsKey(rollback)) {
              remote.remove(target);
              remote[target] = remote.remove(rollback)!;
            } else if (!remote.containsKey(temporary)) {
              remote.remove(target);
            }
          }
          return '';
        },
        download: (remotePath) async => remote[remotePath],
        upload: (bytes, remotePath) async {
          remote[remotePath] = Uint8List.fromList(bytes);
        },
      );

      await expectLater(
        service.restore(backup),
        throwsA(isA<ConfigurationRestoreException>()),
        reason: scenario.name,
      );

      expect(
        remote[destination],
        scenario.previous ? original : isNull,
        reason: scenario.name,
      );
    }
  });

  test('post-finalization settings allow only finish-time keys', () async {
    final temp = await Directory.systemTemp.createTemp('config-settings-test-');
    addTearDown(() => temp.delete(recursive: true));
    final backupDir = Directory(path.join(temp.path, 'backup'))..createSync();
    final original = Uint8List.fromList(
      utf8.encode('''
[scooter]
auto-standby-seconds = 1200
usb0-policy = "always"

[alarm]
enabled = false

[dashboard]
language = "de"
units = "metric"

[updates.mdb]
channel = "stable"
'''),
    );
    final backup = createBackupFixture(
      backupDir,
      files: {
        ConfigurationCategory.settings: {'settings.toml': original},
      },
    );
    Uint8List actual(String alarmLine) => Uint8List.fromList(
      utf8.encode('''
[updates.mdb]
channel = "testing"
[dashboard]
units = "metric"
language = "en"
[alarm]
$alarmLine
[scooter]
usb0-policy = "auto"
auto-standby-seconds = 1200
'''),
    );
    var readback = actual('enabled = false');
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (_) async => '',
      download: (_) async => readback,
      upload: (_, __) async {},
    );

    await service.verify(backup, afterFinalization: true);

    readback = actual('enabled = true');
    await expectLater(
      service.verify(backup, afterFinalization: true),
      throwsA(isA<ConfigurationRestoreException>()),
    );
    readback = Uint8List(0);
    await expectLater(
      service.verify(backup, afterFinalization: true),
      throwsA(isA<ConfigurationRestoreException>()),
    );
    readback = Uint8List.fromList(
      utf8.encode(
        '[scooter]\nauto-standby-seconds = 1200\n'
        '[alarm]\nenabled = false\n[dashboard]\nlanguage = "',
      ),
    );
    await expectLater(
      service.verify(backup, afterFinalization: true),
      throwsA(isA<ConfigurationRestoreException>()),
    );
  });

  test(
    'post-finalization keycards require preserved UIDs as a subset',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'config-keycards-test-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final backupDir = Directory(path.join(temp.path, 'backup'))..createSync();
      final original = Uint8List.fromList(utf8.encode('AAAA\nBBBB\n'));
      final backup = createBackupFixture(
        backupDir,
        files: {
          ConfigurationCategory.keycards: {'authorized_uids.txt': original},
        },
      );
      var readback = Uint8List.fromList(utf8.encode('AAAA\nBBBB\nCCCC\n'));
      final service = ConfigurationPreservationService.withTransport(
        runCommand: (_) async => '',
        download: (_) async => readback,
        upload: (_, __) async {},
      );

      await service.verify(backup, afterFinalization: true);
      await expectLater(
        service.verify(backup),
        throwsA(isA<ConfigurationRestoreException>()),
      );

      readback = Uint8List.fromList(utf8.encode('AAAA\nCCCC\n'));
      await expectLater(
        service.verify(backup, afterFinalization: true),
        throwsA(isA<ConfigurationRestoreException>()),
      );
    },
  );
}
