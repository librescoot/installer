import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/driver_service.dart';

/// Lines below are the real probe output shapes captured on Windows 11 26100
/// against an MDB: healthy, hijacked onto usbser by a forced install, and
/// disabled to force a non-zero CM_PROB_* code.
String _line(String instance, String cls, String svc, String problem,
        String inf) =>
    'PRESENT\t$instance\t$cls\t$svc\t$problem\t$inf\n';

const _instance = r'USB\VID_0525&PID_A4A2\6&3365FBAF&0&8';

void main() {
  group('parseBindingProbe', () {
    test('a Net-class device with no problem is usable', () {
      final d = DriverService.parseBindingProbe(
        0,
        _line(_instance, 'Net', 'USB_RNDIS', '0', 'oem76.inf'),
      );

      expect(d.state, DriverBinding.correct);
      expect(d.isUsable, isTrue);
      expect(d.instanceId, _instance);
      expect(d.currentService, 'usb_rndis');
      expect(d.boundInf, 'oem76.inf');
      expect(d.problemCode, 0);
    });

    test("Windows' own in-box RNDIS6 counts as correct", () {
      // netrndis.inf installs service usbrndis6, and rndiscmp.inf can bind it
      // by MS OS descriptor. Testing the service name for 'rndis' happens to
      // pass here, but the class is what actually decides whether it routes.
      final d = DriverService.parseBindingProbe(
        0,
        _line(_instance, 'Net', 'usbrndis6', '0', 'netrndis.inf'),
      );
      expect(d.state, DriverBinding.correct);
    });

    test('a serial driver claiming the device is the wrong driver', () {
      final d = DriverService.parseBindingProbe(
        0,
        _line(_instance, 'Ports', 'usbser', '0', 'usbser.inf'),
      );

      expect(d.state, DriverBinding.wrongDriver);
      expect(d.isUsable, isFalse);
      expect(d.currentClass, 'ports');
      expect(d.boundInf, 'usbser.inf');
    });

    test('a bound but unstartable device is not correct', () {
      // The case the old class+service test missed: Windows reports a Net
      // binding while the device sits on a problem code and moves no packets.
      // Code 39 is what a rejected driver signature looks like.
      final d = DriverService.parseBindingProbe(
        0,
        _line(_instance, 'Net', 'USB_RNDIS', '39', 'oem76.inf'),
      );

      expect(d.state, DriverBinding.deviceError);
      expect(d.isUsable, isFalse);
      expect(d.problemCode, 39);
    });

    test('a disabled device is not correct', () {
      final d = DriverService.parseBindingProbe(
        0,
        _line(_instance, 'Net', 'USB_RNDIS', '22', 'oem76.inf'),
      );
      expect(d.state, DriverBinding.deviceError);
      expect(d.problemCode, 22);
    });

    test('a device awaiting a driver is the easy case, not an error', () {
      // CM_PROB_FAILED_INSTALL just means nothing is installed yet.
      final withCode = DriverService.parseBindingProbe(
        0,
        _line(_instance, 'USBDevice', '', '28', ''),
      );
      expect(withCode.state, DriverBinding.noDriver);

      final noService = DriverService.parseBindingProbe(
        0,
        _line(_instance, 'USBDevice', '', '0', ''),
      );
      expect(noService.state, DriverBinding.noDriver);
    });

    test('an absent device is reported as absent', () {
      final d = DriverService.parseBindingProbe(0, 'ABSENT\n');
      expect(d.state, DriverBinding.notPresent);
    });

    test('a failed probe is unknown, never absent', () {
      // PowerShell blocked by policy used to look exactly like "no device",
      // and installDriver reported success on that.
      expect(
        DriverService.parseBindingProbe(1, '').state,
        DriverBinding.unknown,
      );
      expect(
        DriverService.parseBindingProbe(0, '').state,
        DriverBinding.unknown,
      );
      expect(
        DriverService.parseBindingProbe(0, 'cannot be loaded because running '
                'scripts is disabled on this system')
            .state,
        DriverBinding.unknown,
      );
    });

    test('a truncated row does not read as a healthy device', () {
      final d = DriverService.parseBindingProbe(0, 'PRESENT\t$_instance\n');
      expect(d.state, DriverBinding.noDriver);
      expect(d.isUsable, isFalse);
    });
  });
}
