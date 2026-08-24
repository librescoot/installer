import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/wait_overlay.dart';

/// The overlay showed elapsed against the plan's static typical while the
/// status line carried a live estimate from actual throughput. The better
/// number was on screen, in the smaller place.
void main() {
  group('estimateRemaining', () {
    test('half done after a minute has about a minute left', () {
      expect(
        estimateRemaining(const Duration(seconds: 60), 0.5),
        const Duration(seconds: 60),
      );
    });

    test('a quarter done after 30s has about 90s left', () {
      expect(
        estimateRemaining(const Duration(seconds: 30), 0.25),
        const Duration(seconds: 90),
      );
    });

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

    test('the estimate falls as the work progresses', () {
      final early = estimateRemaining(const Duration(seconds: 10), 0.1)!;
      final late = estimateRemaining(const Duration(seconds: 80), 0.8)!;
      expect(late, lessThan(early));
    });
  });
}
