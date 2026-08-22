import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/installer_phase.dart';

void main() {
  test('installPlan sits between the health check and the first flash phase', () {
    expect(InstallerPhase.installPlan.index,
        greaterThan(InstallerPhase.healthCheck.index));
    expect(InstallerPhase.installPlan.index,
        lessThan(InstallerPhase.mdbToUms.index));
    expect(MajorStep.forPhase(InstallerPhase.installPlan), MajorStep.connect);
  });

  test('the flash step opens on the UMS switch, with no battery to lift out', () {
    // Removing the main pack meant opening a seatbox that software cannot
    // close again, to get a deactivation the UMS reboot performs anyway.
    expect(MajorStep.mdbFlash.phases.first, InstallerPhase.mdbToUms);
    expect(
      InstallerPhase.values.map((p) => p.name),
      isNot(contains('batteryRemoval')),
    );
  });

  test('installPlan is hidden on a fresh install', () {
    expect(InstallerPhase.installPlan.hiddenUnlessActive, isTrue);
  });

  test('the artifact install is collected after the interactive work', () {
    // It runs in the background from the moment the board boots; this phase
    // is the gate where it is waited on and the single reboot happens. Putting
    // it before pairing would make the user watch an upload they could have
    // spent enrolling cards.
    expect(InstallerPhase.mdbArtifact.index,
        greaterThan(InstallerPhase.keycardSetup.index));
    expect(InstallerPhase.mdbArtifact.index,
        lessThan(InstallerPhase.dbcPrep.index));
    expect(MajorStep.forPhase(InstallerPhase.mdbArtifact), MajorStep.mdbInstall);
  });

  test('the interactive work is the first thing after the board boots', () {
    // Both need a human, and everything else in the flow does not, so they go
    // as early as the board can serve them and the machine work runs behind.
    // They also have to precede the trampoline, which stops and masks
    // librescoot-bluetooth and librescoot-keycard for its whole run with the
    // laptop unplugged.
    expect(InstallerPhase.bluetoothPairing.index,
        greaterThan(InstallerPhase.mdbBoot.index));
    expect(InstallerPhase.keycardSetup.index,
        lessThan(InstallerPhase.mdbArtifact.index));
    expect(InstallerPhase.keycardSetup.index,
        lessThan(InstallerPhase.dbcPrep.index));
    expect(MajorStep.forPhase(InstallerPhase.bluetoothPairing),
        MajorStep.pairing);
    expect(MajorStep.forPhase(InstallerPhase.keycardSetup), MajorStep.pairing);
  });

  test('reconnect is the failure path, not a step of the happy one', () {
    expect(InstallerPhase.reconnect.hiddenUnlessActive, isTrue);
  });

  test('finish is the last phase, so nothing follows the autonomous run', () {
    expect(InstallerPhase.finish.index,
        InstallerPhase.values.length - 1);
    expect(MajorStep.values.last, MajorStep.finish);
  });

  test('every phase belongs to exactly one major step', () {
    for (final phase in InstallerPhase.values) {
      final owners =
          MajorStep.values.where((s) => s.containsPhase(phase)).toList();
      expect(owners.length, 1, reason: '$phase is in ${owners.length} steps');
    }
  });

  test('each major step lists its phases in enum order', () {
    for (final step in MajorStep.values) {
      final indices = step.phases.map((p) => p.index).toList();
      final sorted = [...indices]..sort();
      expect(indices, sorted, reason: '${step.title} is out of order');
    }
  });
}
