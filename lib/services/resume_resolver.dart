import '../models/install_state.dart';
import '../models/installer_phase.dart';
import '../models/trampoline_status.dart';

class ResumeDecision {
  ResumeDecision({
    required this.phase,
    this.skipUnlockGate = false,
    this.bluetoothDone = false,
    this.keycardDone = false,
    this.previousError,
  });

  final InstallerPhase phase;
  final bool skipUnlockGate;
  final bool bluetoothDone;
  final bool keycardDone;
  final String? previousError;
}

/// Pure resume policy. [state] is /data/installer/state.json (null if absent,
/// e.g. stock OS or a fresh device). [status] is /data/installer/trampoline-status
/// (null if absent). USB-mode pre-flash detection is handled by the caller; this
/// function covers the post-flash regime plus the legacy "leftover files" case.
ResumeDecision resolveResume({
  required InstallState? state,
  required TrampolineStatus? status,
}) {
  final err = status?.result == TrampolineResult.error
      ? (status?.message ?? status?.errorLog)
      : null;

  // Legacy: no state.json but trampoline artifacts exist (older builds).
  if (state == null) {
    if (status == null) {
      return ResumeDecision(phase: InstallerPhase.healthCheck);
    }
    return ResumeDecision(
      phase: status.result == TrampolineResult.success
          ? InstallerPhase.finish
          : InstallerPhase.dbcSwapAndFlash,
      skipUnlockGate: true,
      previousError: err,
    );
  }

  switch (state.phase) {
    case InstallPhase.mdbFlashed:
    case InstallPhase.mdbBooted:
      return ResumeDecision(
        phase: InstallerPhase.dashboardPrep,
        skipUnlockGate: true,
      );
    case InstallPhase.btPaired:
      return ResumeDecision(
        phase: InstallerPhase.dashboardPrep,
        skipUnlockGate: true,
        bluetoothDone: true,
      );
    case InstallPhase.keycardEnrolled:
    case InstallPhase.dbcStaged:
      return ResumeDecision(
        phase: InstallerPhase.dashboardPrep,
        skipUnlockGate: true,
        bluetoothDone: true,
        keycardDone: true,
      );
    case InstallPhase.trampolineArmed:
      if (status?.result == TrampolineResult.success) {
        return ResumeDecision(
          phase: InstallerPhase.finish,
          skipUnlockGate: true,
          bluetoothDone: state.btPaired,
          keycardDone: state.keycardEnrolled,
        );
      }
      return ResumeDecision(
        phase: InstallerPhase.dbcSwapAndFlash,
        skipUnlockGate: true,
        bluetoothDone: state.btPaired,
        keycardDone: state.keycardEnrolled,
        previousError: err,
      );
    case InstallPhase.trampolineOk:
    case InstallPhase.finished:
      return ResumeDecision(
        phase: InstallerPhase.finish,
        skipUnlockGate: true,
        bluetoothDone: state.btPaired,
        keycardDone: state.keycardEnrolled,
      );
    case InstallPhase.trampolineErr:
      return ResumeDecision(
        phase: InstallerPhase.dbcSwapAndFlash,
        skipUnlockGate: true,
        bluetoothDone: state.btPaired,
        keycardDone: state.keycardEnrolled,
        previousError: err,
      );
    case InstallPhase.unknown:
      return ResumeDecision(phase: InstallerPhase.healthCheck);
  }
}
