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

    test('voltage is carried alongside the bucketed charge', () {
      // The firmware quantises charge to 25% steps, so 100% spans everything
      // from 12543 mV up. The volts are what separate a healthy pack from one
      // that will not last an install.
      final h = ScooterHealth()
        ..auxCharge = 100
        ..auxVoltageMv = 15020;
      expect(h.auxVoltageMv, 15020);
      expect(h.auxChargeOk, isTrue);
    });

    test('an unread voltage does not affect the verdict', () {
      final h = ScooterHealth()..auxCharge = 100;
      expect(h.auxVoltageMv, isNull);
      expect(h.auxChargeOk, isTrue);
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

  group('main pack charge', () {
    test('a nearly flat pack warns without failing the preconditions', () {
      // The board runs off the AUX battery, so the install completes either
      // way. Blocking on this would stop a run that was going to work.
      final h = ScooterHealth()
        ..auxCharge = 100
        ..cbbStateOfHealth = 95
        ..cbbCharge = 90
        ..batteryPresent = true
        ..batteryCharge = 7;
      expect(h.batteryChargeOk, isFalse);
      expect(h.allOk, isTrue, reason: 'a warning must not gate the install');
    });

    test('ten percent is the line, and it is inclusive', () {
      expect((ScooterHealth()..batteryCharge = 10).batteryChargeOk, isTrue);
      expect((ScooterHealth()..batteryCharge = 9).batteryChargeOk, isFalse);
      expect((ScooterHealth()..batteryCharge = 100).batteryChargeOk, isTrue);
    });

    test('a charge nobody read is not a flat pack', () {
      // battery-service is absent from the bootstrap image, so this field is
      // routinely missing. Rendering that as 0% accuses the hardware.
      expect(ScooterHealth().batteryChargeOk, isNull);
    });
  });
}
