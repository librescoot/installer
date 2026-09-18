import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

void main() {
  group('the macOS disk probe keeps asking', () {
    test('every poll while the board is arriving', () {
      for (var attempts = 0; attempts < 12; attempts++) {
        expect(
          UsbDetector.macDiskProbeDue(
            attempts: attempts,
            sinceLastProbe: const Duration(seconds: 1),
          ),
          isTrue,
          reason: 'attempt $attempts is inside the fast window',
        );
      }
    });

    test('then less often, but not never', () {
      expect(
        UsbDetector.macDiskProbeDue(
          attempts: 40,
          sinceLastProbe: const Duration(seconds: 1),
        ),
        isFalse,
        reason: 'a slow retry must not run at poll speed',
      );
      expect(
        UsbDetector.macDiskProbeDue(
          attempts: 40,
          sinceLastProbe: const Duration(seconds: 15),
        ),
        isTrue,
        reason: 'media that appears late is still media',
      );
    });
  });
}
