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
}

/// [deviceReported] is null when the completion record could not be read,
/// which is the ordinary state once the trampoline is running: the cable is
/// on the dashboard by then, so there is no session to ask over and none to
/// run the handover over either.
FinishHandover finishHandover({
  required bool dryRun,
  required bool linkUp,
  required bool deviceArmed,
  required bool? deviceReported,
}) {
  if (dryRun || !linkUp) return FinishHandover.none;
  if (deviceReported == null) return FinishHandover.none;
  if (deviceArmed && deviceReported) return FinishHandover.none;
  return FinishHandover.run;
}
