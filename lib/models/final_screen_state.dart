/// The honest outcome the final screen can report.
///
/// Device-side finalization is asynchronous. It becomes a confirmed success
/// only after the laptop reconnects and reads this run's completion record.
enum FinalScreenState {
  /// The device is expected to finish and unlock itself; success is unproven.
  finishingOnDevice,

  /// The laptop still occupies the MDB USB port. Restore the internal cable.
  reconnectDbc,

  /// Completion was observed, but the laptop cable still needs swapping back
  /// to the DBC for the scooter to be reassembled.
  completedReconnectDbc,

  /// The completion record for this exact install run was observed.
  completed,
}

/// [dashboardWorkPending] is whether the plan still has anything to do on
/// the far side of the cable swap: dashboard firmware or map tiles. Without
/// it the board finishes on whichever cable is in the port, the laptop's
/// included, so asking for the DBC cable "to continue" would be asking for
/// something the install does not need. The cable still goes back for
/// reassembly, which the confirmed states keep saying.
FinalScreenState finalScreenState({
  required bool laptopOccupiesMdbUsb,
  required bool completionConfirmed,
  bool dashboardWorkPending = true,
}) {
  if (completionConfirmed) {
    return laptopOccupiesMdbUsb
        ? FinalScreenState.completedReconnectDbc
        : FinalScreenState.completed;
  }
  return laptopOccupiesMdbUsb && dashboardWorkPending
      ? FinalScreenState.reconnectDbc
      : FinalScreenState.finishingOnDevice;
}
