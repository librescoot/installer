import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

void main() {
  group('parseWindowsDiskProbe', () {
    test('a disk carrying boot or system is refused', () {
      final probe = UsbDetector.parseWindowsDiskProbe(0, 'system');
      expect(probe.verdict, SystemDiskVerdict.systemDisk);
      expect(probe.present, isTrue);
    });

    test('a disk carrying neither is flashable', () {
      final probe = UsbDetector.parseWindowsDiskProbe(0, 'ok');
      expect(probe.verdict, SystemDiskVerdict.notSystem);
      expect(probe.present, isTrue);
    });

    test('a disk number that no longer enumerates is absent', () {
      // Get-Disk threw and the Win32_DiskDrive filter matched nothing.
      final probe = UsbDetector.parseWindowsDiskProbe(0, 'absent');
      expect(probe.present, isFalse);
    });

    test('an absent disk carries no opinion about boot or system', () {
      expect(UsbDetector.parseWindowsDiskProbe(0, 'absent').verdict,
          SystemDiskVerdict.unknown);
    });

    test('a probe that answered nothing leaves the disk in place', () {
      final probe = UsbDetector.parseWindowsDiskProbe(0, 'unknown');
      expect(probe.verdict, SystemDiskVerdict.unknown);
      expect(probe.present, isTrue);
    });

    test('a failed probe leaves the disk in place', () {
      final probe = UsbDetector.parseWindowsDiskProbe(1, '');
      expect(probe.verdict, SystemDiskVerdict.unknown);
      expect(probe.present, isTrue);
    });

    test('an absent answer from a failed probe is not believed', () {
      expect(UsbDetector.parseWindowsDiskProbe(1, 'absent').present, isTrue);
    });

    test('the answer is read regardless of case and surrounding whitespace',
        () {
      expect(UsbDetector.parseWindowsDiskProbe(0, '  Absent \r\n').present,
          isFalse);
      expect(UsbDetector.parseWindowsDiskProbe(0, ' SYSTEM\n').verdict,
          SystemDiskVerdict.systemDisk);
    });
  });
}
