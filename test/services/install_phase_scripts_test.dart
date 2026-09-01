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
    test('renders the staged artifact path', () {
      final s = MdbArtifactScript.render(
        template: artifactTemplate,
        runId: 'run-1',
        artifactPath: '/data/ota/mdb/release-v2.0.0.mender',
      );
      expect(s, contains('/data/ota/mdb/release-v2.0.0.mender'));
      expect(s, contains('run-1'));
      expect(unresolvedPlaceholders(s), isEmpty);
    });

    test('a plan with no MDB artifact still records a verdict', () {
      // The reboot phase joins on the result file, so a run that leaves the
      // MDB alone has to leave something readable behind or the join waits
      // out its full budget and then calls the run failed.
      final s = MdbArtifactScript.render(
        template: artifactTemplate,
        runId: 'run-1',
      );
      expect(unresolvedPlaceholders(s), isEmpty);
      expect(s, contains('skipped'));
    });

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

    test('records failure rather than leaving the join to guess', () {
      final s = MdbArtifactScript.render(
        template: artifactTemplate,
        runId: 'r',
        artifactPath: '/data/ota/mdb/a.mender',
      );
      expect(s, contains('error: mender-update install exited'));
      expect(s, contains('error: the MDB artifact is missing'));
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

    test('retires before asking for the reboot', () {
      // A reboot that lands with the phase still queued runs it again on the
      // next boot, and the vehicle reboots forever.
      final s = RebootPhaseScript.render(
        template: rebootTemplate,
        runId: 'r',
      );
      expect(s.indexOf('retire'), lessThan(s.indexOf('exit 75')));
    });

    test('only the ok arm reboots', () {
      // case arms are mutually exclusive, so what matters is each arm's
      // contents rather than their order. Rebooting on a failed install would
      // land back on the same image via u-boot's rollback and read as success;
      // rebooting on a skipped one takes a vehicle dark for nothing.
      final s = RebootPhaseScript.render(
        template: rebootTemplate,
        runId: 'r',
      );
      final body = s.substring(s.indexOf(r'case "$RESULT" in'));
      final arms = <String, String>{};
      String? current;
      final buf = StringBuffer();
      for (final line in body.split('\n')) {
        final t = line.trim();
        if (RegExp(r'^(ok|skipped|\*)\)$').hasMatch(t)) {
          if (current != null) arms[current] = buf.toString();
          current = t.substring(0, t.length - 1);
          buf.clear();
        } else if (t == ';;') {
          if (current != null) arms[current] = buf.toString();
          current = null;
          buf.clear();
        } else if (current != null && !t.startsWith('#')) {
          // Comments in these arms legitimately discuss rebooting; only the
          // commands are under test.
          buf.writeln(t);
        }
      }
      expect(arms.keys, containsAll(['ok', 'skipped', '*']));
      // The phase asks; it never reboots. A phase that reboots never returns
      // to be recorded as having run, which made every successful install end
      // with a false "install phases never ran: 80-reboot.sh".
      final invokesReboot = RegExp(r'^reboot\b', multiLine: true);
      for (final arm in arms.values) {
        expect(invokesReboot.hasMatch(arm), isFalse,
            reason: 'the reboot belongs to the coordinator');
      }
      expect(arms['ok'], contains('exit 75'));
      expect(arms['skipped'], contains('exit 0'));
      expect(arms['skipped'], contains('retire'),
          reason: 'it must still retire or it re-runs at every boot');
      expect(arms['*'], contains('exit 1'));
    });

    test('nothing installed here means nothing to reboot for', () {
      // A dashboard-only or tiles-only plan changes nothing on this board. The
      // dashboard was powered off when its work finished and the unlock brings
      // it back on its new image, so a reboot would only take the vehicle dark
      // for a minute.
      final s = RebootPhaseScript.render(
        template: rebootTemplate,
        runId: 'r',
      );
      final skipped = s.indexOf('  skipped)');
      final reboot = s.indexOf('reboot &');
      expect(skipped, greaterThan(0));
      expect(skipped, greaterThan(reboot),
          reason: 'the skipped arm must not fall into the reboot arm');
      expect(s, contains('no reboot is needed'));
    });

    test('the phase numbers order the run correctly', () {
      // 10 starts the MDB write, 20 does the dashboard, 80 joins and reboots,
      // 90 hands the vehicle back on the far side.
      expect(MdbArtifactScript.phaseName, '10-mdb-artifact.sh');
      expect(RebootPhaseScript.phaseName, '80-reboot.sh');
      expect(MdbArtifactScript.phaseName.compareTo('20-dbc.sh'), lessThan(0));
      expect(RebootPhaseScript.phaseName.compareTo('20-dbc.sh'),
          greaterThan(0));
      expect(RebootPhaseScript.phaseName.compareTo('90-finalize.sh'),
          lessThan(0));
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

    test('the reboot phase clears it once the join is done', () {
      final s = RebootPhaseScript.render(
        template: File('assets/reboot-phase.sh.template').readAsStringSync(),
        runId: 'r',
      );
      expect(s.indexOf(r'rm -f "$RESULT_FILE"'),
          lessThan(s.indexOf('exit 75')),
          reason: 'it must not survive into the next boot');
    });
  });
}
