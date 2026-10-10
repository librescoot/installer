import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/install_phase_scripts.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

void main() {
  late String artifactTemplate;
  late String rebootTemplate;

  setUpAll(() {
    artifactTemplate =
        File('assets/mdb-artifact.sh.template').readAsStringSync();
    rebootTemplate = File('assets/reboot-phase.sh.template').readAsStringSync();
  });

  group('shell assets', () {
    test('normalizes Windows line endings before upload', () {
      expect(normalizeShellScript('one\r\ntwo\rthree\n'), 'one\ntwo\nthree\n');
    });
  });

  group('expected phases', () {
    test('expects the dashboard phase only after trampoline handoff', () {
      expect(
        expectedInstallPhases(expectDbcPhase: true),
        ['10-mdb-artifact.sh', '20-dbc.sh', '80-reboot.sh', '90-finalize.sh'],
      );
      expect(
        expectedInstallPhases(expectDbcPhase: false),
        ['10-mdb-artifact.sh', '80-reboot.sh', '90-finalize.sh'],
      );
    });
  });

  group('10-mdb-artifact.sh', () {
    test('the install is backgrounded, not awaited', () {
      // The whole point: the coordinator moves on to the dashboard phase
      // while this writes eMMC.
      final s = MdbArtifactScript.render(
        template: artifactTemplate,
        runId: 'r',
        artifactPath: '/data/ota/mdb/a.mender',
      );
      expect(s, contains('mender-update install'));
      // In its own unit, not a child of the phase: the coordinator's unit is
      // stopped the moment a later phase fails, and systemd takes every
      // process in its cgroup with it, which killed the write mid-slot.
      expect(s, contains('systemd-run --unit=librescoot-mdb-artifact'));
      // Detached where systemd-run is missing, which is only ever a fixture.
      expect(s, contains(r'setsid /bin/sh "$WORKER"'));
      expect(s, contains('exit 0'));
    });

    test('refuses to render with a placeholder left over', () {
      expect(
        () => MdbArtifactScript.render(
          template: '$artifactTemplate\necho {{UNFILLED}}\n',
          runId: 'r',
        ),
        throwsStateError,
      );
    });
  });

  group('80-reboot.sh', () {
    test('renders the join budget in seconds', () {
      final s = RebootPhaseScript.render(
        template: rebootTemplate,
        runId: 'run-1',
        artifactWait: const Duration(minutes: 5),
      );
      expect(s, contains('WAIT_LIMIT=300'));
      expect(unresolvedPlaceholders(s), isEmpty);
    });

  });

  group('the join file survives long enough to be read', () {
    // 80-reboot.sh joins on mdb-artifact.result, and both sweeps run before
    // it does. A swept result reads as an install that never finished, which
    // stops the reboot and leaves the board on the bootstrap image with a
    // fully flashed dashboard.
    test('the shared sweep spares it', () {
      expect(SshService.installerSweepCommand,
          contains('! -name mdb-artifact.result'));
    });

    test("the trampoline's own sweep spares it", () {
      final trampoline =
          File('assets/trampoline.sh.template').readAsStringSync();
      final sweeps = RegExp(r'find "\$INSTALLER_DIR" -mindepth 1')
          .allMatches(trampoline)
          .length;
      expect(sweeps, greaterThan(0), reason: 'the sweep moved or changed');
      expect(trampoline, contains('! -name mdb-artifact.result'));
    });

  });
}
