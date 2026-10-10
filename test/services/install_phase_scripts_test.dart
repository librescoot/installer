import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/install_phase_scripts.dart';

void main() {
  late String artifactTemplate;
  late String rebootTemplate;

  setUpAll(() {
    artifactTemplate = File(
      'assets/mdb-artifact.sh.template',
    ).readAsStringSync();
    rebootTemplate = File('assets/reboot-phase.sh.template').readAsStringSync();
  });

  group('shell assets', () {
    test('normalizes Windows line endings before upload', () {
      expect(normalizeShellScript('one\r\ntwo\rthree\n'), 'one\ntwo\nthree\n');
    });
  });

  group('expected phases', () {
    test('expects the dashboard phase only after trampoline handoff', () {
      expect(expectedInstallPhases(expectDbcPhase: true), [
        '10-mdb-artifact.sh',
        '20-dbc.sh',
        '80-reboot.sh',
        '90-finalize.sh',
      ]);
      expect(expectedInstallPhases(expectDbcPhase: false), [
        '10-mdb-artifact.sh',
        '80-reboot.sh',
        '90-finalize.sh',
      ]);
    });
  });

  group('10-mdb-artifact.sh', () {
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
}
