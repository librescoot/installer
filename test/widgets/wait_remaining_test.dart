import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/wait_overlay.dart';

/// The overlay showed elapsed against the plan's static typical while the
/// status line carried a live estimate from actual throughput. The better
/// number was on screen, in the smaller place.
void main() {
  group('estimateRemaining', () {
    test('too little progress to divide by is no estimate', () {
      // Early fractions turn a rounding error into minutes.
      expect(estimateRemaining(const Duration(seconds: 5), 0.0), isNull);
      expect(estimateRemaining(const Duration(seconds: 5), 0.01), isNull);
    });

    test('a step that reports no progress at all has no estimate', () {
      expect(estimateRemaining(const Duration(seconds: 30), null), isNull);
    });

    test('a complete fraction has nothing left to estimate', () {
      expect(estimateRemaining(const Duration(seconds: 30), 1.0), isNull);
    });

    test('no elapsed time yet is no estimate', () {
      expect(estimateRemaining(Duration.zero, 0.5), isNull);
    });

  });
}
