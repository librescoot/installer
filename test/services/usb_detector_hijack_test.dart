import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

void main() {
  group('modeForPnpClass', () {
    test('a Net-class device is reachable over SSH', () {
      expect(UsbDetector.modeForPnpClass('Net'), DeviceMode.ethernet);
      expect(UsbDetector.modeForPnpClass('net'), DeviceMode.ethernet);
      expect(UsbDetector.modeForPnpClass('  Net  '), DeviceMode.ethernet);
    });

    test('a serial driver holding the device is not ethernet mode', () {
      // The same PnP entity is still enumerated when usbser claims it, named
      // "USB Serial Device (COM5)". Reporting that as ethernet made the
      // installer skip the RNDIS wait and fail at SSH with no explanation.
      expect(UsbDetector.modeForPnpClass('Ports'), DeviceMode.hijacked);
      expect(UsbDetector.modeForPnpClass('Modem'), DeviceMode.hijacked);
      expect(UsbDetector.modeForPnpClass('USBDevice'), DeviceMode.hijacked);
    });

    test('an unknown class is not treated as evidence of a hijack', () {
      // The query failing to return a class says nothing about who holds the
      // device, so it must not flip a working setup into an error state.
      expect(UsbDetector.modeForPnpClass(null), DeviceMode.ethernet);
      expect(UsbDetector.modeForPnpClass(''), DeviceMode.ethernet);
      expect(UsbDetector.modeForPnpClass('   '), DeviceMode.ethernet);
    });
  });
}
