import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/phase_attempt.dart';

void main() {
  test('an attempt starts once until it reaches a terminal state', () {
    final attempt = PhaseAttempt();

    final generation = attempt.begin();

    expect(generation, isNotNull);
    expect(attempt.isRunning, isTrue);
    expect(attempt.begin(), isNull);
    expect(attempt.complete(generation!), isTrue);
    expect(attempt.status, PhaseAttemptStatus.completed);
    expect(attempt.begin(), isNull);
  });

  test('a failed attempt can be retried exactly once', () {
    final attempt = PhaseAttempt();
    final first = attempt.begin()!;

    expect(attempt.fail(first, 'timed out'), isTrue);
    expect(attempt.isFailed, isTrue);
    expect(attempt.error, 'timed out');

    final retry = attempt.begin();
    expect(retry, isNotNull);
    expect(retry, isNot(first));
    expect(attempt.begin(), isNull);
    expect(attempt.isRunning, isTrue);
  });

  test('reset invalidates late completion before phase re-entry', () {
    final attempt = PhaseAttempt();
    final staleGeneration = attempt.begin()!;

    attempt.reset();

    expect(attempt.status, PhaseAttemptStatus.ready);
    expect(attempt.complete(staleGeneration), isFalse);
    expect(attempt.fail(staleGeneration, 'late'), isFalse);
    expect(attempt.status, PhaseAttemptStatus.ready);
  });
}
