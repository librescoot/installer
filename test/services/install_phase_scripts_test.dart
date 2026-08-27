import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/install_phase_scripts.dart';

void main() {
  late String artifactTemplate;
  late String rebootTemplate;

  setUpAll(() {
    artifactTemplate =
        File('assets/mdb-artifact.sh.template').readAsStringSync();
    rebootTemplate = File('assets/reboot-phase.sh.template').readAsStringSync();
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
      expect(s, matches(RegExp(r'\)\s*>/dev/null 2>&1 &')));
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

    test('retires itself before rebooting, never at the top', () {
      // A reboot that lands with the phase still queued runs it again on the
      // next boot, and the vehicle reboots forever.
      final s = RebootPhaseScript.render(
        template: rebootTemplate,
        runId: 'r',
      );
      final retire = s.indexOf("rm -f \"\$SCRIPTS_DIR/80-reboot.sh\"");
      final reboot = s.indexOf('reboot &');
      expect(retire, greaterThan(0));
      expect(reboot, greaterThan(retire),
          reason: 'the retire must precede the reboot');
    });

    test('does not reboot when the MDB artifact failed', () {
      // u-boot would roll back to the image already running and the run would
      // read as successful.
      final s = RebootPhaseScript.render(
        template: rebootTemplate,
        runId: 'r',
      );
      final guard = s.indexOf('not rebooting:');
      final reboot = s.indexOf('reboot &');
      expect(guard, greaterThan(0));
      expect(guard, lessThan(reboot),
          reason: 'the failure branch must exit before the reboot');
      expect(s, contains('exit 1'));
    });

    test('skipped counts as a reason to reboot', () {
      // A dashboard-only plan still has to activate the dashboard image.
      final s = RebootPhaseScript.render(
        template: rebootTemplate,
        runId: 'r',
      );
      expect(s, contains('ok|skipped)'));
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
}
