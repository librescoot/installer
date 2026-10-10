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

  group('serial download', () {
    test('a board in its boot ROM is waited on, not proceeded past', () {
      // Seen on hardware: the boot after a flash found nothing bootable and
      // the board enumerated as the i.MX boot ROM for two minutes. Everything
      // that was not mass storage used to count as running the image, which
      // would have had the installer SSH into a boot ROM.
      expect(
        mdbBootActionFor(mode: DeviceMode.recoveryMdb, sawRestart: true),
        MdbBootAction.waitForRecovery,
      );
      expect(
        mdbBootActionFor(mode: DeviceMode.recoveryDbc, sawRestart: true),
        MdbBootAction.waitForRecovery,
      );
    });

    test('it is the same answer before a restart was seen', () {
      // A board in its boot ROM has plainly restarted, but the verdict does
      // not depend on having watched it happen.
      expect(
        mdbBootActionFor(mode: DeviceMode.recoveryMdb, sawRestart: false),
        MdbBootAction.waitForRecovery,
      );
    });

  });
}
