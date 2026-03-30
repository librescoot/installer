import 'app_localizations.dart';
import '../models/installer_phase.dart';

extension InstallerPhaseL10n on InstallerPhase {
  String localizedTitle(AppLocalizations l10n) => switch (this) {
        InstallerPhase.welcome => l10n.phaseWelcomeTitle,
        InstallerPhase.physicalPrep => l10n.phasePhysicalPrepTitle,
        InstallerPhase.mdbConnect => l10n.phaseMdbConnectTitle,
        InstallerPhase.healthCheck => l10n.phaseHealthCheckTitle,
        InstallerPhase.batteryRemoval => l10n.phaseBatteryRemovalTitle,
        InstallerPhase.mdbToUms => l10n.phaseMdbToUmsTitle,
        InstallerPhase.mdbFlash => l10n.phaseMdbFlashTitle,
        InstallerPhase.scooterPrep => l10n.phaseScooterPrepTitle,
        InstallerPhase.mdbBoot => l10n.phaseMdbBootTitle,
        InstallerPhase.cbbReconnect => l10n.phaseCbbReconnectTitle,
        InstallerPhase.dbcPrep => l10n.phaseDbcPrepTitle,
        InstallerPhase.dbcFlash => l10n.phaseDbcFlashTitle,
        InstallerPhase.reconnect => l10n.phaseReconnectTitle,
        InstallerPhase.finish => l10n.phaseFinishTitle,
      };

  String localizedDescription(AppLocalizations l10n) => switch (this) {
        InstallerPhase.welcome => l10n.phaseWelcomeDescription,
        InstallerPhase.physicalPrep => l10n.phasePhysicalPrepDescription,
        InstallerPhase.mdbConnect => l10n.phaseMdbConnectDescription,
        InstallerPhase.healthCheck => l10n.phaseHealthCheckDescription,
        InstallerPhase.batteryRemoval => l10n.phaseBatteryRemovalDescription,
        InstallerPhase.mdbToUms => l10n.phaseMdbToUmsDescription,
        InstallerPhase.mdbFlash => l10n.phaseMdbFlashDescription,
        InstallerPhase.scooterPrep => l10n.phaseScooterPrepDescription,
        InstallerPhase.mdbBoot => l10n.phaseMdbBootDescription,
        InstallerPhase.cbbReconnect => l10n.phaseCbbReconnectDescription,
        InstallerPhase.dbcPrep => l10n.phaseDbcPrepDescription,
        InstallerPhase.dbcFlash => l10n.phaseDbcFlashDescription,
        InstallerPhase.reconnect => l10n.phaseReconnectDescription,
        InstallerPhase.finish => l10n.phaseFinishDescription,
      };
}
