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
}
