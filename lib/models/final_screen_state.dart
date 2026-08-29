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

FinalScreenState finalScreenState({
  required bool laptopOccupiesMdbUsb,
  required bool completionConfirmed,
}) {
  if (completionConfirmed) {
    return laptopOccupiesMdbUsb
        ? FinalScreenState.completedReconnectDbc
        : FinalScreenState.completed;
  }
  return laptopOccupiesMdbUsb
      ? FinalScreenState.reconnectDbc
      : FinalScreenState.finishingOnDevice;
}
