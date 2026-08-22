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
MdbBootAction mdbBootActionFor({
  required DeviceMode? mode,
  required bool sawRestart,
}) {
  if (mode == null) return MdbBootAction.waitForDevice;
  if (mode == DeviceMode.massStorage) {
    return sawRestart ? MdbBootAction.reflash : MdbBootAction.waitForRestart;
  }
  return MdbBootAction.proceed;
}
