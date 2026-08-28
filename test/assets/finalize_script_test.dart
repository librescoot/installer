import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/finalize_script.dart';

/// The last thing that runs on a scooter, on both paths, frequently with
/// nobody watching. What it does with a failed install matters as much as what
/// it does with a good one.
void main() {
  final templateFile = File('assets/finalize.sh.template');
  late String template;

  setUpAll(() => template = templateFile.readAsStringSync());

  String render({
    String mdbAction = 'upgrade',
    String runId = 'run-test-1',
    String mode = 'upgrade',
    String language = 'de',
    String channel = 'stable',
    String region = '',
    String dashboardResult = 'not-requested',
  }) =>
      FinalizeScript.render(
        template: template,
        mdbAction: mdbAction,
        runId: runId,
        mode: mode,
        language: language,
        channel: channel,
        dbcVersion: 'v1.2.1',
        region: region,
        dashboardResult: dashboardResult,
      );

  group('rendering', () {
    test('a rendered script has nothing left to fill', () {
      expect(FinalizeScript.unresolvedPlaceholders(render()), isEmpty);
    });

    test('records a skipped dashboard transfer without a region', () {
      final script = render(dashboardResult: 'skipped');
      expect(script, contains('DASHBOARD_RESULT="skipped"'));
      expect(script, contains('TILES_REGION=""'));
    });

    test('it refuses rather than shipping a hole', () {
      // An unfilled placeholder is valid shell in most of the places one
      // appears, so the script would run and take the wrong branch.
      expect(
        () => FinalizeScript.render(
          template: '$template\nEXTRA="{{SOMETHING_NEW}}"\n',
          mdbAction: 'upgrade',
          runId: 'r',
          mode: 'upgrade',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('every placeholder the template carries is one we fill', () {
      expect(FinalizeScript.unresolvedPlaceholders(render()), isEmpty,
          reason: 'the template gained a placeholder the renderer ignores');
    });
  });

  group('running it', () {
    late Directory root;
    late String calls;

    Future<void> stubs({String serviceModeActive = 'false'}) async {
      final bin = Directory('${root.path}/bin');
      await bin.create(recursive: true);
      final entries = {
        'redis-cli': '''#!/bin/sh
echo "redis-cli \$*" >> "\$CALLS"
case "\$*" in
  *"hget settings dashboard.service-mode-active"*) echo $serviceModeActive ;;
esac
''',
        'lsc': '#!/bin/sh\necho "lsc \$*" >> "\$CALLS"\n',
        'systemctl': '''#!/bin/sh
echo "systemctl \$*" >> "\$CALLS"
case "\$1" in is-active) echo active ;; esac
''',
        'sleep': '#!/bin/sh\nexit 0\n',
        // The signalling reaches the vehicle through these three and nothing
        // else, so they are what says what the finish lit.
        'ioctl': '#!/bin/sh\necho "ioctl \$*" >> "\$CALLS"\n',
        'i2cset': '#!/bin/sh\necho "i2cset \$*" >> "\$CALLS"\n',
        'systemd-run': '#!/bin/sh\nfor a in "\$@"; do case "\$a" in '
            '--unit=*) echo "unit \${a#--unit=}" >> "\$CALLS" ;; esac; done\n',
      };
      for (final e in entries.entries) {
        final f = File('${bin.path}/${e.key}');
        await f.writeAsString(e.value);
        await Process.run('chmod', ['+x', f.path]);
      }
    }

    Future<ProcessResult> run({
      String mdbAction = 'upgrade',
      String? status,
      String serviceModeActive = 'false',
      String runId = 'run-test-1',
      String imageId = '',
      String bootedRoot = '/dev/mmcblk1p3',
      String? previousRoot,
    }) async {
      await stubs(serviceModeActive: serviceModeActive);
      await Directory('${root.path}/installer').create(recursive: true);
      if (status != null) {
        await File('${root.path}/installer/trampoline-status')
            .writeAsString('$status\n');
      }
      final script = File('${root.path}/installer/scripts/90-finalize.sh');
      await script.parent.create(recursive: true);
      // Staged beside the phase the way the installer stages it. Without it
      // the finish runs on a vehicle that says nothing at all.
      await File('${script.parent.path}/signal.sh').writeAsString(
        File('assets/signal.sh')
            .readAsStringSync()
            .replaceAll('/data/', '${root.path}/'),
      );
      await script.writeAsString(
        render(mdbAction: mdbAction, runId: runId)
            .replaceAll('/data/', '${root.path}/'),
      );
      if (previousRoot != null) {
        await File('${root.path}/installer/previous-root')
            .writeAsString('$previousRoot\n');
      }
      final cmdline = File('${root.path}/cmdline');
      await cmdline.writeAsString('root=$bootedRoot quiet loglevel=5\n');
      final osRelease = File('${root.path}/os-release');
      await osRelease.writeAsString(
        'ID=librescoot-mdb\nVERSION_ID=2.0.0\n'
        '${imageId.isEmpty ? '' : 'IMAGE_ID=$imageId\n'}',
      );
      return Process.run('sh', [
        script.path
      ], environment: {
        'PATH': '${root.path}/bin:${Platform.environment['PATH']}',
        'CALLS': calls,
        'OS_RELEASE': osRelease.path,
        'CMDLINE': cmdline.path,
      });
    }

    Future<List<String>> callLog() async =>
        File(calls).existsSync() ? File(calls).readAsLines() : <String>[];

    setUp(() async {
      root = await Directory.systemTemp.createTemp('finalize-');
      calls = '${root.path}/calls.log';
    });
    tearDown(() => root.delete(recursive: true));

    test('an upgrade gets the pre-install settings back', () async {
      await Directory('${root.path}/installer').create(recursive: true);
      await File('${root.path}/settings.toml.preinstall')
          .writeAsString('# the user had these\n');
      final result = await run(mdbAction: 'upgrade');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(await File('${root.path}/settings.toml').readAsString(),
          contains('the user had these'));
    });

    test('a clean install wipes them instead', () async {
      await Directory('${root.path}/installer').create(recursive: true);
      await File('${root.path}/settings.toml').writeAsString('# ours\n');
      final result = await run(mdbAction: 'cleanInstall');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(File('${root.path}/settings.toml').existsSync(), isFalse);
    });

    test('with no backup and a live overlay it writes no defaults', () async {
      // settings-service reads a non-overlay value written to an overlaid key
      // as a deliberate edit, moves its captured base to it, and hands that
      // back on the clear. Writing 900 here loses whatever was configured.
      final result = await run(mdbAction: 'upgrade', serviceModeActive: 'true');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      expect(log.any((l) => l.contains('auto-standby-seconds 900')), isFalse);
      expect(log.any((l) => l.contains('alarm.enabled true')), isFalse);
    });

    test('with no backup and no overlay it does reset the two keys', () async {
      final result = await run(mdbAction: 'upgrade', serviceModeActive: 'false');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      expect(log.any((l) => l.contains('auto-standby-seconds 900')), isTrue);
      expect(log.any((l) => l.contains('alarm.enabled true')), isTrue);
    });

    test('service mode ends before the policy is restored', () async {
      final result = await run();
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      final clear = log.indexWhere((l) => l.contains('clear:service'));
      final policy = log.indexWhere((l) => l.contains('usb0-policy auto'));
      expect(clear, isNot(-1));
      expect(policy, greaterThan(clear),
          reason: 'a policy write before the clear lands gets re-asserted');
      expect(File('${root.path}/service-mode.json').existsSync(), isFalse);
    });

    test('a good run unlocks and records what it installed', () async {
      final result = await run(status: 'success', runId: 'run-good');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect((await callLog()).any((l) => l.contains('scooter:state unlock')),
          isTrue);
      final record = await File(
              '${root.path}/installer/history/run-good/record')
          .readAsString();
      expect(record, contains('result: success'));
      expect(record, contains('run-id: run-good'));
      expect(record, contains('mdb: 2.0.0'));
      expect(record, contains('dashboard-result: not-requested'));
      expect(await File('${root.path}/installer/last-install').readAsString(),
          contains('run-id: run-good'));
    });

    test('a good run ends with the bar complete and the vehicle dark',
        () async {
      // Segment 4 is this phase. Leaving it breathing would show a run still
      // finalising on a scooter that has already unlocked itself, and a green
      // LED would be a second success signal competing with the unlock the
      // owner was told to wait for.
      final result = await run(status: 'success');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      expect(log, contains('unit librescoot-bootled-guard'),
          reason: 'amber has to be held while the finish runs');
      expect(log.any((l) => l.contains('ioctl /dev/pwm_led6 0x0000754A -v 150')),
          isTrue, reason: 'segment 4 never filled');
      // The last thing written to the LP5562 is all three channels at zero,
      // which is the LED going out rather than changing colour.
      final led = log.where((l) => l.startsWith('i2cset')).toList();
      expect(led.sublist(led.length - 3), [
        'i2cset -f -y 2 0x30 0x02 0x00',
        'i2cset -f -y 2 0x30 0x03 0x00',
        'i2cset -f -y 2 0x30 0x04 0x00',
      ]);
      expect(log.indexOf('systemctl stop librescoot-bootled-guard.service'),
          lessThan(log.indexWhere((l) => l.contains('scooter:state unlock'))),
          reason: 'the guard would put amber back over the dark LED');
      expect(log, isNot(contains('unit librescoot-bootled-hazards')));
      // The bar is gone, so nothing reads it as a run still going.
      expect(File('${root.path}/installer/trampoline-phase').existsSync(),
          isFalse);
    });

    test('a failed run flashes the hazards rather than going quiet', () async {
      // Nobody is at the laptop by this point. A failed handover that just
      // stops leaves a locked scooter with no light saying why, and the owner
      // has no way to tell it from one still working.
      final result = await run(status: 'error: something went wrong');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      expect(log, contains('unit librescoot-bootled-blink'));
      expect(log, contains('unit librescoot-bootled-hazards'));
      expect(log.any((l) => l.contains('scooter:state unlock')), isFalse);
    });

    test('a failed run stays reachable so it can be retried', () async {
      // Ending service mode puts usb0-policy back to auto, and with keycards
      // paired and the dashboard dark that closes the gate and takes the link
      // down. On a failed install that removes the only way back in at the
      // moment it is needed most.
      await File('${root.path}/service-mode.json')
          .writeAsString('{"active":true,"name":"service"}');
      final result = await run(
          status: 'error: dbc never answered', serviceModeActive: 'true');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();

      expect(log.any((l) => l.contains('clear:service')), isFalse,
          reason: 'the retry needs the link the overlay is holding open');
      expect(log.any((l) => l.contains('usb0-policy auto')), isFalse);
      expect(File('${root.path}/service-mode.json').existsSync(), isTrue,
          reason: 'and it has to survive the reboots before the retry');

      // Started anyway: a service left stopped here stays stopped, and what
      // keeps a failed board awake is the overlay's own pm settings.
      expect(log.any((l) => l.contains('start librescoot-pm')), isTrue);
      expect(log.any((l) => l.contains('restart librescoot-vehicle')), isTrue);

      expect(log.any((l) => l.contains('scooter:state unlock')), isFalse,
          reason: 'unlocking contradicts the error the user is looking at');
      expect(
          File('${root.path}/installer/history/run-test-1/record').existsSync(),
          isFalse,
          reason: 'no success record for a run that did not succeed');
    });

    test('a good run does end it, which is what takes the link down', () async {
      await File('${root.path}/service-mode.json')
          .writeAsString('{"active":true,"name":"service"}');
      final result =
          await run(status: 'success', serviceModeActive: 'false');
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = await callLog();
      expect(log.any((l) => l.contains('clear:service')), isTrue);
      expect(log.any((l) => l.contains('usb0-policy auto')), isTrue);
      expect(File('${root.path}/service-mode.json').existsSync(), isFalse);
    });

    test('it removes itself so the coordinator can retire', () async {
      await run();
      expect(
          File('${root.path}/installer/scripts/90-finalize.sh').existsSync(),
          isFalse);
    });
    group('what it does when the install did not land', () {
      test('a rolled-back board is not unlocked', () async {
        // u-boot rolls back a rootfs that does not commit, and the board comes
        // up on the bootstrap image answering everything happily. The sweep
        // already took the status file, so absence reads as success: without
        // this guard the scooter unlocks having installed nothing.
        await run(status: null, imageId: 'librescoot-mdb-bootstrap');
        expect(await callLog(), isNot(contains(contains('scooter:state unlock'))));
      });

      test('a board on the image it installed is unlocked', () async {
        // The full images set no IMAGE_ID at all, so absence is the good case.
        await run(status: 'success');
        expect(await callLog(), contains(contains('scooter:state unlock')));
      });

      test('the dashboard bootstrap marker counts too', () async {
        await run(status: 'success', imageId: 'librescoot-dbc-bootstrap');
        expect(await callLog(), isNot(contains(contains('scooter:state unlock'))));
      });

      test('it stays queued when it declines, so a retry has a handover',
          () async {
        // The coordinator ignores exit codes and runs this straight after a
        // failed reboot phase. Removing itself there left the boot that
        // finally succeeded with nothing to hand the vehicle back: right
        // image, locked, service mode, alarm parked, indefinitely.
        await run(status: 'error: mender-update install exited 3');
        expect(
          File('${root.path}/installer/scripts/90-finalize.sh').existsSync(),
          isTrue,
          reason: 'a decline is a verdict on this attempt, not the install',
        );
      });

      test('it retires itself once it has handed the vehicle back', () async {
        await run(status: 'success');
        expect(
          File('${root.path}/installer/scripts/90-finalize.sh').existsSync(),
          isFalse,
        );
      });

      test('coming back on the slot the reboot left is a rollback', () async {
        // u-boot rolls back an image that fails to boot, and the rolled-back
        // board is a full image os-release cannot tell from a good one. The
        // trampoline verdict predates the reboot, so "success" in the status
        // file proves nothing about what is running now.
        await run(
          status: 'success',
          bootedRoot: '/dev/mmcblk1p2',
          previousRoot: '/dev/mmcblk1p2',
        );
        expect(await callLog(), isNot(contains(contains('scooter:state unlock'))));
        expect(
          File('${root.path}/installer/history/run-test-1/record').existsSync(),
          isFalse,
          reason: 'a rolled-back install must not write a success record',
        );
        expect(
          await File('${root.path}/installer/trampoline-status').readAsString(),
          contains('rolled back'),
        );
        expect(
          File('${root.path}/installer/previous-root').existsSync(),
          isTrue,
          reason: 'a rollback does not heal, so every retry must see it too',
        );
      });

      test('a different slot is the installed image, and the marker goes',
          () async {
        await run(
          status: 'success',
          bootedRoot: '/dev/mmcblk1p3',
          previousRoot: '/dev/mmcblk1p2',
        );
        expect(await callLog(), contains(contains('scooter:state unlock')));
        expect(
          File('${root.path}/installer/previous-root').existsSync(),
          isFalse,
          reason: 'left behind it would fail the next run that lands here',
        );
      });

      test('no marker means no reboot happened, and no verdict either',
          () async {
        // A run with no MDB artifact never reboots and never writes the
        // marker. The guard has nothing to say about it.
        await run(status: 'success', previousRoot: null);
        expect(await callLog(), contains(contains('scooter:state unlock')));
      });
    });

  });
}
