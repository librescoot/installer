import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/scooter_health.dart';

/// A threshold applied to a value that was never read answers about the read,
/// not about the hardware. Rendered as a bool it becomes a failed check, which
/// is what a stock board's health screen showed: ?% against >= 50%.
void main() {
  group('unmeasured is not measured', () {
    test('an unread value has no verdict', () {
      final h = ScooterHealth();
      expect(h.auxChargeOk, isNull);
      expect(h.cbbSohOk, isNull);
      expect(h.cbbChargeOk, isNull);
    });

    test('a read value is compared to its threshold', () {
      final h = ScooterHealth()
        ..auxCharge = 100
        ..cbbCharge = 79
        ..cbbStateOfHealth = 80;
      expect(h.auxChargeOk, isTrue);
      expect(h.cbbChargeOk, isFalse);
      expect(h.cbbSohOk, isTrue);
    });

    test('zero is a reading, not a gap', () {
      expect((ScooterHealth()..auxCharge = 0).auxChargeOk, isFalse);
    });
  });

  group('allOk', () {
    test('every precondition measured and met', () {
      final h = ScooterHealth()
        ..auxCharge = 60
        ..cbbCharge = 90
        ..cbbStateOfHealth = 95
        ..batteryPresent = true;
      expect(h.allOk, isTrue);
    });

    test('an unread precondition does not pass', () {
      final h = ScooterHealth()
        ..auxCharge = 60
        ..cbbCharge = 90
        ..batteryPresent = true;
      expect(h.allOk, isFalse);
    });

    test('nothing read at all does not pass', () {
      expect(ScooterHealth().allOk, isFalse);
    });
  });
}
