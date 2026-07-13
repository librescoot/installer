import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/installer_phase.dart';

void main() {
  group('phase model (two-stage)', () {
    test('dashboardPrep is in the MDB-prep major step', () {
      expect(MajorStep.forPhase(InstallerPhase.dashboardPrep), MajorStep.mdbPrep);
    });
    test('bluetooth and keycard are merged into dashboardPrep and hidden', () {
      expect(InstallerPhase.bluetoothPairing.hiddenUnlessActive, isTrue);
      expect(InstallerPhase.keycardSetup.hiddenUnlessActive, isTrue);
    });
    test('dbcSwapAndFlash is the only happy-path DBC phase', () {
      expect(MajorStep.dbc.phases, contains(InstallerPhase.dbcSwapAndFlash));
      expect(InstallerPhase.dbcSwapAndFlash.hiddenUnlessActive, isFalse);
      // reconnect belongs to the DBC step so the sidebar shows it active (not
      // completed) during recovery, but it stays hidden on the happy path.
      expect(InstallerPhase.reconnect.hiddenUnlessActive, isTrue);
    });
    test('finish major step only holds finish', () {
      expect(MajorStep.finish.phases, [InstallerPhase.finish]);
    });
    test('every non-hidden phase belongs to exactly one MajorStep', () {
      for (final p in InstallerPhase.values) {
        if (p.hiddenUnlessActive) continue;
        final hits = MajorStep.values.where((s) => s.containsPhase(p)).length;
        expect(hits, 1, reason: '$p should be in exactly one MajorStep');
      }
    });
  });
}
