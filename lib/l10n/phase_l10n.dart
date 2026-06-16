import 'app_localizations.dart';
import '../models/installer_phase.dart';

extension MajorStepL10n on MajorStep {
  String localizedTitle(AppLocalizations l10n) => switch (this) {
        MajorStep.prepare => l10n.majorStepPrepare,
        MajorStep.connect => l10n.majorStepConnect,
        MajorStep.mdbFlash => l10n.majorStepMdbFlash,
        MajorStep.mdbPrep => l10n.majorStepMdbPrep,
        MajorStep.dbc => l10n.majorStepDbcFlash,
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
        InstallerPhase.batteryRemoval => l10n.phaseBatteryRemovalTitle,
        InstallerPhase.mdbToUms => l10n.phaseMdbToUmsTitle,
        InstallerPhase.mdbFlash => l10n.phaseMdbFlashTitle,
        InstallerPhase.scooterPrep => l10n.phaseScooterPrepTitle,
        InstallerPhase.mdbBoot => l10n.phaseMdbBootTitle,
        InstallerPhase.cbbReconnect => l10n.phaseCbbReconnectTitle,
        InstallerPhase.dashboardPrep => l10n.phaseDashboardPrepTitle,
        InstallerPhase.dbcSwapAndFlash => l10n.phaseDbcSwapAndFlashTitle,
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
        InstallerPhase.batteryRemoval => l10n.phaseBatteryRemovalDescription,
        InstallerPhase.mdbToUms => l10n.phaseMdbToUmsDescription,
        InstallerPhase.mdbFlash => l10n.phaseMdbFlashDescription,
        InstallerPhase.scooterPrep => l10n.phaseScooterPrepDescription,
        InstallerPhase.mdbBoot => l10n.phaseMdbBootDescription,
        InstallerPhase.cbbReconnect => l10n.phaseCbbReconnectDescription,
        InstallerPhase.dashboardPrep => l10n.phaseDashboardPrepDescription,
        InstallerPhase.dbcSwapAndFlash => l10n.phaseDbcSwapAndFlashDescription,
        InstallerPhase.reconnect => l10n.phaseReconnectDescription,
        InstallerPhase.bluetoothPairing => l10n.phaseBluetoothPairingDescription,
        InstallerPhase.keycardSetup => l10n.phaseKeycardSetupDescription,
        InstallerPhase.finish => l10n.phaseFinishDescription,
      };
}
