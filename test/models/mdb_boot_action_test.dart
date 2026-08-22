import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/mdb_boot_action.dart';
import 'package:librescoot_installer/services/usb_detector.dart' show DeviceMode;

void main() {
  test('mass storage before a restart is the flash we just finished', () {
    // Treating this as a failed flash re-writes a correctly written board, and
    // does it exactly while the user is pulling power for the restart.
    expect(
        mdbBootActionFor(mode: DeviceMode.massStorage, sawRestart: false),
        MdbBootAction.waitForRestart);
  });

  test('mass storage after a restart is a flash that did not take', () {
    expect(mdbBootActionFor(mode: DeviceMode.massStorage, sawRestart: true),
        MdbBootAction.reflash);
  });

  test('a board running the image proceeds, restart seen or not', () {
    // The mirror mistake: waiting for a disappearance that already happened.
    // A board that is up never goes away again, so that wait never ends.
    for (final saw in [true, false]) {
      expect(mdbBootActionFor(mode: DeviceMode.ethernet, sawRestart: saw),
          MdbBootAction.proceed,
          reason: 'sawRestart=$saw');
    }
  });

  test('nothing on the bus means keep waiting for it', () {
    for (final saw in [true, false]) {
      expect(mdbBootActionFor(mode: null, sawRestart: saw),
          MdbBootAction.waitForDevice);
    }
  });

  test('no input leads to reflash unless a restart was actually observed', () {
    // The only route to re-writing a board is mass storage with a restart
    // behind it. Anything else must not destroy what is on the eMMC.
    for (final mode in [null, DeviceMode.ethernet, DeviceMode.massStorage]) {
      expect(mdbBootActionFor(mode: mode, sawRestart: false),
          isNot(MdbBootAction.reflash),
          reason: '$mode with no restart seen');
    }
  });
}
