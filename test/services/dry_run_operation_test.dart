import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/phase_attempt.dart';
import 'package:librescoot_installer/services/critical_operation_coordinator.dart';
import 'package:librescoot_installer/services/dry_run_operation.dart';

void main() {
  group('DryRunReconnectOperation', () {
    test(
      'uses the real attempt generation to suppress stale completion',
      () async {
        final delay = Completer<void>();
        final attempt = PhaseAttempt();
        final staleGeneration = attempt.begin()!;
        var phase = 'reconnect';
        var status = 'waiting';
        var processing = true;

        final operation = const DryRunReconnectOperation().execute(
          delay: () => delay.future,
          owns: () => attempt.isCurrent(staleGeneration),
          onOwned: () {
            phase = 'finish';
            status = 'successful';
            processing = false;
          },
        );
        attempt.reset();
        attempt.begin();
        delay.complete();
        await operation;

        expect(phase, 'reconnect');
        expect(status, 'waiting');
        expect(processing, isTrue);
      },
    );
  });

  group('DryRunUploadOperation', () {
    test('releases its lease when a stale upload is superseded', () async {
      final coordinator = CriticalOperationCoordinator(onChanged: (_) {});
      final delay = Completer<void>();
      var owns = true;
      final operation = const DryRunUploadOperation().execute(
        coordinator: coordinator,
        delay: () => delay.future,
        owns: () => owns,
        onOwned: () => fail('stale upload must not complete'),
      );
      owns = false;
      delay.complete();
      await operation;

      expect(coordinator.isCritical, isFalse);
    });

    test('releases its lease after normal completion', () async {
      final coordinator = CriticalOperationCoordinator(onChanged: (_) {});
      var completed = false;

      await const DryRunUploadOperation().execute(
        coordinator: coordinator,
        delay: () async {},
        owns: () => true,
        onOwned: () => completed = true,
      );

      expect(completed, isTrue);
      expect(coordinator.isCritical, isFalse);
    });

    test('releases its lease when completion throws', () async {
      final coordinator = CriticalOperationCoordinator(onChanged: (_) {});

      await expectLater(
        const DryRunUploadOperation().execute(
          coordinator: coordinator,
          delay: () async {},
          owns: () => true,
          onOwned: () => throw StateError('dry-run failure'),
        ),
        throwsStateError,
      );
      expect(coordinator.isCritical, isFalse);
    });
  });
}
