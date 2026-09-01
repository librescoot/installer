import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

/// diskutil pads its value column to the widest label in the block, so the
/// column moves between disks and OS versions. Matching the layout instead of
/// the field reported a removable UMS gadget as fixed.
void main() {
  group('parseMacRemovable', () {
    test('removable is read whatever the column width', () {
      for (final pad in [' ', '   ', '              ', '\t']) {
        expect(
          UsbDetector.parseMacRemovable('   Removable Media:$pad Removable\n'),
          isTrue,
          reason: 'pad ${pad.length}',
        );
      }
    });

    test('fixed media is read as fixed', () {
      expect(
        UsbDetector.parseMacRemovable('   Removable Media:      Fixed\n'),
        isFalse,
      );
    });

    test('an absent field has no answer', () {
      expect(UsbDetector.parseMacRemovable('   Protocol:  USB\n'), isNull);
    });

    test('the field is found among the rest of the block', () {
      const info = '''
   Device Identifier:        disk16
   Device Node:              /dev/disk16
   Removable Media:          Removable
   Protocol:                 USB
   Disk Size:                7.8 GB (7818182656 Bytes) (exactly 15269888 512-Byte-Units)
''';
      expect(UsbDetector.parseMacRemovable(info), isTrue);
    });

    test('a value that is neither is not guessed at', () {
      expect(
        UsbDetector.parseMacRemovable('   Removable Media:   Ejectable\n'),
        isNull,
      );
    });
  });
}
