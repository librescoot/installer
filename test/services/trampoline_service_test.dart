import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/models/trampoline_status.dart';
import 'package:librescoot_installer/services/trampoline_service.dart';

void main() {
  group('DBC bootloader tool staging', () {
    Future<ByteData> loadTool(String path) async {
      final bytes = path.endsWith('.config') ? [1, 2] : [3, 4, 5];
      return Uint8List.fromList(bytes).buffer.asByteData();
    }

    test(
      'verifies both files and the executable bit before returning',
      () async {
        final commands = <String>[];
        final uploads = <String, Uint8List>{};

        await stageDbcBootloaderTools(
          loadAsset: loadTool,
          uploadFile: (content, remotePath) async {
            uploads[remotePath] = content;
          },
          runCommand: (command) async {
            commands.add(command);
            return command.startsWith('if test ') ? 'ready' : '';
          },
        );

        expect(
          uploads.keys,
          containsAll(<String>[
            '/data/installer/fwtools/stock-dbc/fw_setenv',
            '/data/installer/fwtools/stock-dbc/fw_env.config',
          ]),
        );
        expect(
          commands,
          contains('chmod 755 /data/installer/fwtools/stock-dbc/fw_setenv'),
        );
        final verification = commands.singleWhere(
          (command) => command.startsWith('if test '),
        );
        expect(
          verification,
          contains('test -s /data/installer/fwtools/stock-dbc/fw_setenv'),
        );
        expect(
          verification,
          contains('test -x /data/installer/fwtools/stock-dbc/fw_setenv'),
        );
        expect(
          verification,
          contains('test -s /data/installer/fwtools/stock-dbc/fw_env.config'),
        );
      },
    );

    test('propagates a missing bundled asset', () async {
      await expectLater(
        stageDbcBootloaderTools(
          loadAsset: (path) => throw StateError('missing $path'),
          uploadFile: (content, remotePath) async {},
          runCommand: (command) async => '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('propagates a remote upload failure', () async {
      await expectLater(
        stageDbcBootloaderTools(
          loadAsset: loadTool,
          uploadFile: (content, remotePath) =>
              throw StateError('upload failed for $remotePath'),
          runCommand: (command) async => '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects missing or empty remote tools', () async {
      await expectLater(
        stageDbcBootloaderTools(
          loadAsset: loadTool,
          uploadFile: (content, remotePath) async {},
          runCommand: (command) async =>
              command.startsWith('if test ') ? 'missing' : '',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('remote verification'),
          ),
        ),
      );
    });
  });

  group('install run state', () {
    test('run IDs are safe for remote filenames', () {
      final runId = createInstallRunId(
        now: DateTime.utc(2026, 8, 24, 7, 12, 34),
        processId: 1234,
      );
      expect(runId, matches(RegExp(r'^run-[a-z0-9]+-[a-z0-9]+$')));
    });

    test('serializes installer phase progress with sequence ordering', () {
      final state = serializeInstallRunState(
        runId: 'run-abc-1',
        actor: 'installer',
        stage: 'healthCheck',
        sequence: 7,
        updatedAt: DateTime.utc(2026, 8, 24, 7, 12, 34),
      );
      expect(state, contains('run-id: run-abc-1\n'));
      expect(state, contains('actor: installer\n'));
      expect(state, contains('stage: healthCheck\n'));
      expect(state, contains('result: running\n'));
      expect(state, contains('finish: pending\n'));
      expect(state, contains('sequence: 7\n'));
    });

    test('arming clears the old completion before launching the new run', () {
      final source =
          File('lib/services/trampoline_service.dart').readAsStringSync();
      final start = source.indexOf('Future<void> start({required String runId})');
      final clear = source.indexOf('rm -f /data/last-install', start);
      final launch = source.indexOf('nohup /data/installer/trampoline.sh', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(clear, greaterThan(start));
      expect(launch, greaterThan(clear));
    });
  });

  group('remoteDirOf', () {
    test('returns the directory component of a path with a slash', () {
      expect(remoteDirOf('/data/ota/mdb/librescoot-unu-mdb-v1.2.1.mender'),
          '/data/ota/mdb');
    });

    test('returns null for a bare filename with no directory', () {
      expect(remoteDirOf('librescoot-unu-mdb-v1.2.1.mender'), isNull);
    });

    test('returns null for a path rooted directly at / (nothing to create)', () {
      expect(remoteDirOf('/file.mender'), isNull);
    });
  });

  group('TrampolineStatus', () {
    test('parses success', () {
      final status = TrampolineStatus.parse('success\nAll done in 5m');
      expect(status.result, TrampolineResult.success);
      expect(status.message, 'All done in 5m');
    });

    test('parses error', () {
      final status = TrampolineStatus.parse(
        'error: DBC UMS device not found\nlog line 1\nlog line 2',
      );
      expect(status.result, TrampolineResult.error);
      expect(status.errorLog, contains('log line'));
    });

    test('an in-flight job is not a success', () {
      // The trampoline writes this before the reboot that hands over to
      // onboot.sh, so the dashboard has not been touched yet.
      final status = TrampolineStatus.parse('running\nmode: flash\nmdb: v1.2.1');
      expect(status.result, TrampolineResult.running);
      expect(status.mode, 'flash');
      expect(status.mdbVersion, 'v1.2.1');
    });

    test('the older rebooting verdict reads as running, not success', () {
      final status = TrampolineStatus.parse('rebooting\nlog line');
      expect(status.result, TrampolineResult.running);
    });

    test('handles empty content', () {
      final status = TrampolineStatus.parse('');
      expect(status.result, TrampolineResult.unknown);
    });

    test('keeps the verdict on the first line and reads the extra fields', () {
      final status = TrampolineStatus.parse(
          'success\nrun-id: run-abc-1\nfinish: complete\n'
          'stage: complete\nmode: upgrade\nmdb: v1.2.1\ndbc: v1.2.1\n');
      expect(status.result, TrampolineResult.success);
      expect(status.runId, 'run-abc-1');
      expect(status.finishState, 'complete');
      expect(status.stage, 'complete');
      expect(status.mode, 'upgrade');
      expect(status.mdbVersion, 'v1.2.1');
      expect(status.dbcVersion, 'v1.2.1');
    });

    test('only a complete matching run can prove autonomous finish', () {
      final complete = TrampolineStatus.parseCompletionRecord(
        'result: success\nrun-id: run-abc-1\nfinish: complete\n',
      );
      final pending = TrampolineStatus.parseCompletionRecord(
        'result: success\nrun-id: run-abc-1\nfinish: pending\n',
      );
      expect(complete.completedFor('run-abc-1'), isTrue);
      expect(complete.completedFor('run-old-9'), isFalse);
      expect(pending.completedFor('run-abc-1'), isFalse);
    });

    test('parses shared current-run progress', () {
      final state = InstallRunState.parse(
        'run-id: run-abc-1\nactor: trampoline\nstage: waiting-dbc-ssh\n'
        'result: running\nfinish: pending\n',
      );
      expect(state.runId, 'run-abc-1');
      expect(state.actor, 'trampoline');
      expect(state.stage, 'waiting-dbc-ssh');
      expect(state.result, TrampolineResult.running);
      expect(state.toTrampolineStatus().stage, 'waiting-dbc-ssh');
    });

    test('a flash-mode status without the extra fields still parses', () {
      final status = TrampolineStatus.parse('success\nAll done in 5m');
      expect(status.result, TrampolineResult.success);
      expect(status.mode, isNull);
      expect(status.message, 'All done in 5m');
    });

    test('a value-less field line reads as absent, not as an empty version', () {
      // The trampoline writes `dbc: $(cat ...)`, which comes out as a bare
      // `dbc: ` on a job that installed no artifact.
      final status =
          TrampolineStatus.parse('success\nmode: flash\ndbc: \nlog line');
      expect(status.mode, 'flash');
      expect(status.dbcVersion, isNull);
    });

    test('an artifact failure is an error, not a success', () {
      final status = TrampolineStatus.parse(
          'error: DBC not reachable, artifact not installed\nlog line');
      expect(status.result, TrampolineResult.error);
      expect(status.message, contains('artifact not installed'));
    });
  });

  group('Region', () {
    test('catalogue covers the 15 German regions plus neighbours', () {
      expect(Region.all.length, 20);
      final germanCount =
          Region.all.where((r) => r.country == 'Deutschland').length;
      expect(germanCount, 15);
    });

    test('berlin_brandenburg slug is correct', () {
      final region = Region.all.firstWhere((r) => r.name.contains('Berlin'));
      expect(region.slug, 'berlin_brandenburg');
      expect(region.country, 'Deutschland');
    });

    test('fromSlug humanises unknown slugs under the catch-all country', () {
      final region = Region.fromSlug('italy-nord-est');
      expect(region.name, 'Italy Nord Est');
      expect(region.country, 'Weitere');
    });

    test('equality and hashCode are by slug', () {
      const a = Region(name: 'Bayern', slug: 'bayern', country: 'Deutschland');
      final b = Region.fromSlug('bayern');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('renderTemplate', () {
    const fixture = '''
MODE="{{MODE}}"
DBC_IMAGE="{{DBC_IMAGE_PATH}}"
DBC_MENDER="{{DBC_MENDER_PATH}}"
DBC_TARGET="{{DBC_TARGET_VERSION}}"
INSTALL_TILES={{INSTALL_TILES}}
OSM="{{OSM_TILES_FILE}}"
VALHALLA="{{VALHALLA_TILES_FILE}}"
''';

    test('renders flash mode with an image and an artifact', () {
      final out = TrampolineService.renderTemplate(
        fixture,
        upgradeMode: false,
        dbcImagePath: '/data/installer/librescoot-unu-dbc-minimal-v1.2.1.sdimg.gz',
        dbcMenderPath: '/data/installer/librescoot-unu-dbc-v1.2.1.mender',
      );
      expect(out, contains('MODE="flash"'));
      expect(out,
          contains('DBC_IMAGE="/data/installer/librescoot-unu-dbc-minimal-v1.2.1.sdimg.gz"'));
      expect(out,
          contains('DBC_MENDER="/data/installer/librescoot-unu-dbc-v1.2.1.mender"'));
      expect(out, contains('INSTALL_TILES=false'));
    });

    test('renders upgrade mode with no image at all', () {
      final out = TrampolineService.renderTemplate(
        fixture,
        upgradeMode: true,
        dbcImagePath: '',
        dbcMenderPath: '/data/installer/librescoot-unu-dbc-v1.2.1.mender',
      );
      expect(out, contains('MODE="upgrade"'));
      expect(out, contains('DBC_IMAGE=""'));
    });

    test('renders the target version the DBC is verified against', () {
      final out = TrampolineService.renderTemplate(
        fixture,
        upgradeMode: true,
        dbcImagePath: '',
        dbcMenderPath: '/data/installer/librescoot-unu-dbc-v1.2.1.mender',
        dbcTargetVersion: 'v1.2.1',
      );
      expect(out, contains('DBC_TARGET="v1.2.1"'));
    });

    test('an unset target renders empty rather than leaving a placeholder', () {
      final out = TrampolineService.renderTemplate(
        fixture,
        upgradeMode: true,
        dbcImagePath: '',
        dbcMenderPath: '/data/installer/librescoot-unu-dbc-v1.2.1.mender',
      );
      expect(out, contains('DBC_TARGET=""'));
    });

    test('an on-device finish renders the plan into the script', () {
      final out = TrampolineService.renderTemplate(
        '$fixture\nF={{FINISH_ON_DEVICE}} A={{MDB_ACTION}} V={{MDB_TARGET_VERSION}} '
        'L={{FINISH_LANGUAGE}} C={{FINISH_CHANNEL}}',
        upgradeMode: true,
        dbcImagePath: '',
        dbcMenderPath: '/data/installer/a.mender',
        finish: const DeviceFinish(
          onDevice: true,
          mdbAction: BoardAction.upgrade,
          mdbTargetVersion: 'v1.2.1',
          language: 'de',
          otaChannel: 'stable',
        ),
      );
      expect(out, contains('F=true'));
      expect(out, contains('A=upgrade'));
      expect(out, contains('V=v1.2.1'));
      expect(out, contains('L=de'));
      expect(out, contains('C=stable'));
    });

    test('the default is the old behaviour: hand back to the laptop', () {
      final out = TrampolineService.renderTemplate(
        '$fixture\nF={{FINISH_ON_DEVICE}} A={{MDB_ACTION}}',
        upgradeMode: true,
        dbcImagePath: '',
        dbcMenderPath: '/data/installer/a.mender',
      );
      expect(out, contains('F=false'));
      expect(out, contains('A=leave'));
    });

    test('leaves no placeholder behind', () {
      final out = TrampolineService.renderTemplate(
        fixture,
        upgradeMode: true,
        dbcImagePath: '',
        dbcMenderPath: '',
        installTiles: true,
        region: const Region(
            name: 'Berlin', slug: 'berlin_brandenburg', country: 'Deutschland'),
      );
      expect(out, isNot(contains('{{')));
      expect(out, contains('INSTALL_TILES=true'));
      expect(out, contains('/data/installer/tiles_berlin_brandenburg.mbtiles'));
    });

    test('rejects upgrade mode with no artifact and no tiles', () {
      expect(
        () => TrampolineService.renderTemplate(
          fixture,
          upgradeMode: true,
          dbcImagePath: '',
          dbcMenderPath: '',
          installTiles: false,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
