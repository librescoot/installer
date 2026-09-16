import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/configuration_preservation.dart';
import 'package:librescoot_installer/services/configuration_preservation_service.dart';
import 'package:path/path.dart' as path;

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
    File(path.join(backupDir.path, 'manifest.json')).writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'files': [
          {
            'category': 'wireGuard',
            'source': '/data/wireguard/wg0.conf',
            'restore': '/data/wireguard/wg0.conf',
            'localName': 'wg0.conf',
            'bytes': expected.length,
          },
        ],
      }),
    );
    final remote = <String, Uint8List>{};
    final commands = <String>[];
    final events = <String>[];
    final service = ConfigurationPreservationService.withTransport(
      runCommand: (command) async {
        commands.add(command);
        events.add('command:$command');
        final rename = RegExp(
          r"^mv -f '([^']+)' '([^']+)'$",
        ).firstMatch(command);
        if (rename != null) {
          remote[rename.group(2)!] = remote.remove(rename.group(1)!)!;
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
    final rename = events.indexWhere((event) => event.contains('mv -f'));
    expect(prepare, greaterThanOrEqualTo(0));
    expect(upload, greaterThan(prepare));
    expect(rename, greaterThan(upload));
  });

  test('restore failure retains and reports the backup path', () async {
    final temp = await Directory.systemTemp.createTemp('config-restore-fail-');
    addTearDown(() => temp.delete(recursive: true));
    final backupDir = Directory(path.join(temp.path, 'backup'))
      ..createSync(recursive: true);
    File(path.join(backupDir.path, 'manifest.json')).writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'files': [
          {
            'category': 'settings',
            'restore': '/etc/passwd',
            'localName': 'settings.toml',
          },
        ],
      }),
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
}
