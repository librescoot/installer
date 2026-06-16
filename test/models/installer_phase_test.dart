import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/installer_phase.dart';

void main() {
  group('phase model (two-stage)', () {
    test('dashboardPrep is in the MDB-prep major step', () {
      expect(MajorStep.forPhase(InstallerPhase.dashboardPrep), MajorStep.mdbPrep);
    });
    test('bluetooth and keycard are Stage 1, not Finish', () {
      expect(MajorStep.forPhase(InstallerPhase.bluetoothPairing), MajorStep.mdbPrep);
      expect(MajorStep.forPhase(InstallerPhase.keycardSetup), MajorStep.mdbPrep);
    });
    test('dbcSwapAndFlash is the only happy-path DBC phase', () {
      expect(MajorStep.dbc.phases, contains(InstallerPhase.dbcSwapAndFlash));
      expect(MajorStep.dbc.phases, isNot(contains(InstallerPhase.reconnect)));
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
