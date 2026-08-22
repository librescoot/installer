import 'app_localizations.dart';
import '../models/installer_phase.dart';

extension MajorStepL10n on MajorStep {
  /// [upgrade] switches the board install steps to their upgrade wording. A
  /// user who picked Upgrade because it keeps their settings should not then
  /// watch a step called "Flash MDB".
  ///
  /// mdbFlash keeps its name on both paths: it is the step that prepares the
  /// board for a raw write, which an upgrade skips. Naming it after the
  /// upgrade puts the same title on the skipped step and on mdbInstall, which
  /// is the step actually doing the upgrade, and reads as if the upgrade
  /// itself had been skipped.
  String localizedTitle(AppLocalizations l10n, {bool upgrade = false}) =>
      switch (this) {
        MajorStep.prepare => l10n.majorStepPrepare,
        MajorStep.connect => l10n.majorStepConnect,
        MajorStep.mdbFlash => l10n.majorStepMdbFlash,
        MajorStep.pairing => l10n.majorStepPairing,
        MajorStep.mdbInstall =>
          upgrade ? l10n.majorStepMdbUpgrade : l10n.majorStepMdbInstall,
        MajorStep.dbcFlash =>
          upgrade ? l10n.majorStepDbcUpgrade : l10n.majorStepDbcFlash,
        MajorStep.finish => l10n.majorStepFinish,
      };
}

extension InstallerPhaseL10n on InstallerPhase {
  String localizedTitle(AppLocalizations l10n) => switch (this) {
        InstallerPhase.welcome => l10n.phaseWelcomeTitle,
        InstallerPhase.notices => l10n.phaseNoticesTitle,
        InstallerPhase.physicalPrep => l10n.phasePhysicalPrepTitle,
        InstallerPhase.mdbConnect => l10n.phaseMdbConnectTitle,
        InstallerPhase.resumeDetected => l10n.phaseResumeDetectedTitle,
        InstallerPhase.healthCheck => l10n.phaseHealthCheckTitle,
        InstallerPhase.installPlan => l10n.phaseInstallPlanTitle,
        InstallerPhase.mdbToUms => l10n.phaseMdbToUmsTitle,
        InstallerPhase.mdbFlash => l10n.phaseMdbFlashTitle,
        InstallerPhase.scooterPrep => l10n.phaseScooterPrepTitle,
        InstallerPhase.mdbBoot => l10n.phaseMdbBootTitle,
        InstallerPhase.mdbArtifact => l10n.phaseMdbArtifactTitle,
        InstallerPhase.cbbReconnect => l10n.phaseCbbReconnectTitle,
        InstallerPhase.dbcPrep => l10n.phaseDbcPrepTitle,
        InstallerPhase.dbcFlash => l10n.phaseDbcFlashTitle,
        InstallerPhase.reconnect => l10n.phaseReconnectTitle,
        InstallerPhase.bluetoothPairing => l10n.phaseBluetoothPairingTitle,
        InstallerPhase.keycardSetup => l10n.phaseKeycardSetupTitle,
        InstallerPhase.finish => l10n.phaseFinishTitle,
      };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
        InstallerPhase.welcome => l10n.phaseWelcomeDescription,
        InstallerPhase.notices => l10n.phaseNoticesDescription,
        InstallerPhase.physicalPrep => l10n.phasePhysicalPrepDescription,
        InstallerPhase.mdbConnect => l10n.phaseMdbConnectDescription,
        InstallerPhase.resumeDetected => l10n.phaseResumeDetectedDescription,
        InstallerPhase.healthCheck => l10n.phaseHealthCheckDescription,
        InstallerPhase.installPlan => l10n.phaseInstallPlanDescription,
        InstallerPhase.mdbToUms => l10n.phaseMdbToUmsDescription,
        InstallerPhase.mdbFlash => l10n.phaseMdbFlashDescription,
        InstallerPhase.scooterPrep => l10n.phaseScooterPrepDescription,
        InstallerPhase.mdbBoot => l10n.phaseMdbBootDescription,
        InstallerPhase.mdbArtifact => l10n.phaseMdbArtifactDescription,
        InstallerPhase.cbbReconnect => l10n.phaseCbbReconnectDescription,
        InstallerPhase.dbcPrep => l10n.phaseDbcPrepDescription,
        InstallerPhase.dbcFlash => l10n.phaseDbcFlashDescription,
        InstallerPhase.reconnect => l10n.phaseReconnectDescription,
        InstallerPhase.bluetoothPairing => l10n.phaseBluetoothPairingDescription,
        InstallerPhase.keycardSetup => l10n.phaseKeycardSetupDescription,
        InstallerPhase.finish => l10n.phaseFinishDescription,
      };
}
