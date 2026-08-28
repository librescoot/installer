/// Whether the laptop still has a finish to run when the last screen opens.
///
/// The device closes its own install out when the trampoline was armed with
/// it: settings, services, the usb0 policy and the unlock all happen there.
/// The laptop's copy of that work exists for the runs where it did not, and
/// every step of it needs an SSH session to the MDB.
enum FinishHandover {
  /// Nothing for the laptop to do: show the finish screen.
  none,

  /// Restore what this run changed and wait for the unlock.
  run,

  /// The laptop owes the finish and cannot do it. Distinct from [none],
  /// because on a run with no trampoline the finish is the whole install:
  /// the artifact is staged, no phase has been queued and nothing else will
  /// queue one. Showing the success screen here leaves the owner
  /// reassembling a scooter that was never installed.
  blocked,
}

/// [deviceReported] is null when the completion record could not be read.
///
/// What that means depends entirely on [deviceArmed]. With a trampoline
/// running it is the ordinary state: the cable is on the dashboard, there is
/// no session to ask over and none to run the handover over either, and the
/// device closes itself out. Without one it means the question could not be
/// put, over a link that never moved, and the work is still owed.
FinishHandover finishHandover({
  required bool dryRun,
  required bool linkUp,
  required bool deviceArmed,
  required bool? deviceReported,
}) {
  // Nothing was staged, so there is nothing to owe.
  if (dryRun) return FinishHandover.none;

  if (deviceArmed) {
    if (!linkUp) return FinishHandover.none;
    if (deviceReported == null) return FinishHandover.none;
    return deviceReported ? FinishHandover.none : FinishHandover.run;
  }

  if (!linkUp) return FinishHandover.blocked;
  if (deviceReported == null) return FinishHandover.blocked;
  return deviceReported ? FinishHandover.none : FinishHandover.run;
}
