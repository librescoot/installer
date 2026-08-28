/// The honest outcome the final screen can report.
///
/// Device-side finalization is asynchronous. It becomes a confirmed success
/// only after the laptop reconnects and reads this run's completion record.
enum FinalScreenState {
  /// The device is expected to finish and unlock itself; success is unproven.
  finishingOnDevice,

  /// The laptop is occupying the MDB USB port on a plan that needs the DBC.
  /// It must be swapped back before device-side work can continue.
  reconnectDbc,

  /// Completion was observed, but the laptop cable still needs swapping back
  /// to the DBC for the scooter to be reassembled.
  completedReconnectDbc,

  /// The completion record for this exact install run was observed.
  completed,
}

FinalScreenState finalScreenState({
  required bool planNeedsHandoff,
  required bool laptopAttached,
  required bool completionConfirmed,
}) {
  if (completionConfirmed) {
    return laptopAttached
        ? FinalScreenState.completedReconnectDbc
        : FinalScreenState.completed;
  }
  if (planNeedsHandoff && laptopAttached) return FinalScreenState.reconnectDbc;
  return FinalScreenState.finishingOnDevice;
}
