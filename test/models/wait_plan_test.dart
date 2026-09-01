import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/wait_plan.dart';

/// The overdue mark is the whole point of showing typical times: it turns
/// "this is taking forever" into something the screen says before the user
/// decides it for themselves and unplugs.
void main() {
  test('a step inside its usual time is not overdue', () {
    expect(
      waitStepIsOverdue(const Duration(seconds: 30), const Duration(minutes: 1)),
      isFalse,
    );
  });

  test('a step barely over gets the grace period', () {
    // Boards vary; a few seconds either way is not news.
    expect(
      waitStepIsOverdue(const Duration(seconds: 65), const Duration(minutes: 1)),
      isFalse,
    );
  });

  test('a step well past its usual time is called out', () {
    expect(
      waitStepIsOverdue(const Duration(seconds: 95), const Duration(minutes: 1)),
      isTrue,
    );
  });

  group('the stall hint waits for abnormal, not for slow', () {
    test('it cannot fire inside the time a healthy board takes', () {
      // The hint names the host's network stack as a likely cause. Firing it
      // while the board is still doing what it does on every good run accuses
      // something innocent, and tells the operator to act when the correct
      // response is to keep waiting.
      expect(stableConnectionStallAfter, greaterThan(stableConnectionTypical));
    });

    test('with margin, because healthy runs vary', () {
      // The run that prompted this warned at 90s against a 135s typical, then
      // recovered on its own thirty seconds later and finished clean. A
      // threshold a hair past typical would have done the same thing.
      expect(
        stableConnectionStallAfter.inSeconds,
        greaterThanOrEqualTo(stableConnectionTypical.inSeconds * 3 ~/ 2),
        reason: 'too close to typical to survive a slow-but-healthy board',
      );
    });

    test('and still bounded, so a genuinely dead link is not silent forever',
        () {
      expect(stableConnectionStallAfter.inMinutes, lessThanOrEqualTo(10));
    });
  });
}
