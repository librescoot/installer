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

  group('supersede', () {
    // The reconnect flow offers a retry while a run is still in flight. It
    // relies on reset() to make the older run's guards fail, so that two runs
    // never write the same substeps or share one SSH session.
    test('a restart makes the older run stale', () {
      final attempt = PhaseAttempt();
      final first = attempt.begin()!;
      expect(attempt.isCurrent(first), isTrue);

      attempt.reset();
      final second = attempt.begin()!;

      expect(second, isNot(first));
      expect(attempt.isCurrent(second), isTrue);
      expect(attempt.isCurrent(first), isFalse,
          reason: 'the superseded run must stop touching shared state');
    });

    test('a stale run cannot complete or fail the live one', () {
      final attempt = PhaseAttempt();
      final stale = attempt.begin()!;
      attempt.reset();
      final live = attempt.begin()!;

      expect(attempt.complete(stale), isFalse);
      expect(attempt.fail(stale, 'boom'), isFalse);
      expect(attempt.isCurrent(live), isTrue);
      expect(attempt.error, isNull);
    });

    test('reset lets a completed attempt run again', () {
      // begin() refuses on a completed attempt, so a retry after success has
      // to reset first. The reconnect flow resets unconditionally on entry.
      final attempt = PhaseAttempt();
      final first = attempt.begin()!;
      attempt.complete(first);
      expect(attempt.begin(), isNull);

      attempt.reset();
      expect(attempt.begin(), isNotNull);
    });
  });
}
