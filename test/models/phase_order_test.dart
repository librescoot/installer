import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/installer_phase.dart';

void main() {
  int idx(InstallerPhase p) => p.index;

  test('the interactive block comes before the CBB step and the dashboard', () {
    // The sidebar numbers steps by phase order, so any route that reaches the
    // CBB step before pairing walks the user backwards through the list.
    expect(idx(InstallerPhase.bluetoothPairing),
        lessThan(idx(InstallerPhase.keycardSetup)));
    expect(idx(InstallerPhase.keycardSetup),
        lessThan(idx(InstallerPhase.cbbReconnect)));
    expect(idx(InstallerPhase.cbbReconnect),
        lessThan(idx(InstallerPhase.dbcPrep)));
  });

  test('the artifact gate sits between the cards and the CBB step', () {
    expect(idx(InstallerPhase.keycardSetup),
        lessThan(idx(InstallerPhase.mdbArtifact)));
    expect(idx(InstallerPhase.mdbArtifact),
        lessThan(idx(InstallerPhase.cbbReconnect)));
  });

  test('every major step covers a contiguous run of phases', () {
    for (final step in MajorStep.values) {
      final indices = step.phases.map(idx).toList()..sort();
      expect(indices.last - indices.first, indices.length - 1,
          reason: '${step.title} straddles phases belonging to another step');
    }
  });

  test('the major steps themselves are in phase order', () {
    final firsts = MajorStep.values
        .map((s) => s.phases.map(idx).reduce((a, b) => a < b ? a : b))
        .toList();
    final sorted = [...firsts]..sort();
    expect(firsts, sorted);
  });
}
