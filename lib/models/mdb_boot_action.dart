import '../services/usb_detector.dart' show DeviceMode;

/// What the boot phase should do next, given what the USB detector reports.
enum MdbBootAction {
  /// Still in mass storage and no restart seen: the board is in the state a
  /// finished flash leaves it in, waiting for the user to restart it.
  waitForRestart,

  /// Nothing on the bus. It is on its way back.
  waitForDevice,

  /// Back in mass storage after a restart. The image did not take.
  reflash,

  /// The board is sitting in its own boot ROM: it looked for something to
  /// boot and found nothing. Not a brick, and not something to act on. The
  /// nRF re-arms a power cycle when Linux never checks in, and the boot after
  /// that has been seen to succeed.
  waitForRecovery,

  /// Running the image. Carry on.
  proceed,
}

/// The decision the boot phase makes, separated from the waiting so it can be
/// reasoned about.
///
/// The trap here is that mass storage means two opposite things depending on
/// whether a restart has happened yet. Before one, it is the state a
/// successful flash leaves behind, and acting on it re-writes a board that was
/// written correctly, at the moment its power is being pulled. After one, it
/// means the image did not take. Nothing in the mode alone distinguishes them.
///
/// The mirror mistake is waiting for a restart that already happened: a board
/// that is running the image never goes away again, so the wait never ends.
///
/// Serial-download mode is its own answer and not [proceed]. Anything that is
/// not mass storage used to count as running the image, which would have had
/// the installer open an SSH session against a boot ROM.
MdbBootAction mdbBootActionFor({
  required DeviceMode? mode,
  required bool sawRestart,
}) {
  if (mode == null) return MdbBootAction.waitForDevice;
  if (mode == DeviceMode.recoveryMdb || mode == DeviceMode.recoveryDbc) {
    return MdbBootAction.waitForRecovery;
  }
  if (mode == DeviceMode.massStorage) {
    return sawRestart ? MdbBootAction.reflash : MdbBootAction.waitForRestart;
  }
  return MdbBootAction.proceed;
}
