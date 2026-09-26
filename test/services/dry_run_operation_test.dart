import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/phase_attempt.dart';
import 'package:librescoot_installer/services/critical_operation_coordinator.dart';
import 'package:librescoot_installer/models/substep.dart';
import 'package:librescoot_installer/services/dry_run_operation.dart';
import 'package:librescoot_installer/services/trampoline_service.dart';

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

  group('simulateDryRunUpload', () {
    const mb = 1024 * 1024;
    const files = [
      DryRunFile('dashboard image', 600 * mb),
      DryRunFile('dashboard firmware', 200 * mb),
      DryRunFile('map tiles', 200 * mb),
    ];

    test('reports the real staging steps and finishes each one', () async {
      final snapshots = <List<Substep>>[];
      final progress = <double>[];
      await simulateDryRunUpload(
        files: files,
        stagesImage: true,
        labels: const SubstepLabels(),
        onSubsteps: snapshots.add,
        onProgress: (_, p) => progress.add(p),
        owns: () => true,
        total: const Duration(seconds: 10),
        sleep: (_) async {},
      );

      expect(snapshots.first.map((s) => s.label), [
        'Check existing files',
        'Upload dashboard image',
        'Upload dashboard firmware',
        'Upload map tiles',
        'Upload flasher tool',
        'Upload DBC bootloader tools',
        'Upload trampoline script',
      ]);
      expect(
        snapshots.first.every((s) => s.state == SubstepState.pending),
        isTrue,
      );
      expect(snapshots.last.every((s) => s.state == SubstepState.done), isTrue);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
      expect(progress.last, 1.0);
    });

    test('shows a byte count while a file is active', () async {
      final details = <String>[];
      await simulateDryRunUpload(
        files: files,
        stagesImage: false,
        labels: const SubstepLabels(),
        onSubsteps: (steps) {
          for (final s in steps) {
            if (s.state == SubstepState.active && s.detail != null) {
              details.add(s.detail!);
            }
          }
        },
        onProgress: (_, _) {},
        owns: () => true,
        total: const Duration(seconds: 10),
        sleep: (_) async {},
      );

      expect(details.any((d) => d.startsWith('600 / 600 MB')), isTrue);
      expect(details.every((d) => d.contains('remaining')), isTrue);
    });

    test('stops when a newer upload takes over', () async {
      var ticks = 0;
      final snapshots = <List<Substep>>[];
      await simulateDryRunUpload(
        files: files,
        stagesImage: true,
        labels: const SubstepLabels(),
        onSubsteps: snapshots.add,
        onProgress: (_, _) {},
        owns: () => ticks < 5,
        total: const Duration(seconds: 10),
        sleep: (_) async => ticks++,
      );

      expect(snapshots.last.any((s) => s.state != SubstepState.done), isTrue);
    });
  });
}
