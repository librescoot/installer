import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/window_close_coordinator.dart';

void main() {
  group('WindowCloseCoordinator', () {
    test('refuses a close request during a critical operation', () async {
      var cleanupCalls = 0;
      var closeCalls = 0;
      final coordinator = WindowCloseCoordinator();

      final closed = await coordinator.requestClose(
        isCritical: true,
        cleanup: () async {
          cleanupCalls++;
        },
        closeWindow: () async {
          closeCalls++;
        },
      );

      expect(closed, isFalse);
      expect(cleanupCalls, 0);
      expect(closeCalls, 0);
    });

    test('cleans up before closing a noncritical window', () async {
      final calls = <String>[];
      final coordinator = WindowCloseCoordinator();

      final closed = await coordinator.requestClose(
        isCritical: false,
        cleanup: () async {
          calls.add('cleanup');
        },
        closeWindow: () async {
          calls.add('close');
        },
      );

      expect(closed, isTrue);
      expect(calls, ['cleanup', 'close']);
    });

    test('still closes when best-effort cleanup fails', () async {
      var closeCalls = 0;
      final coordinator = WindowCloseCoordinator();

      final closed = await coordinator.requestClose(
        isCritical: false,
        cleanup: () async => throw StateError('device disappeared'),
        closeWindow: () async {
          closeCalls++;
        },
      );

      expect(closed, isTrue);
      expect(closeCalls, 1);
    });

    test('coalesces concurrent close requests', () async {
      final cleanupStarted = Completer<void>();
      final releaseCleanup = Completer<void>();
      var closeCalls = 0;
      final coordinator = WindowCloseCoordinator();

      final first = coordinator.requestClose(
        isCritical: false,
        cleanup: () async {
          cleanupStarted.complete();
          await releaseCleanup.future;
        },
        closeWindow: () async {
          closeCalls++;
        },
      );
      await cleanupStarted.future;
      final second = coordinator.requestClose(
        isCritical: false,
        cleanup: () async => fail('second cleanup must not run'),
        closeWindow: () async => fail('second close must not run'),
      );
      releaseCleanup.complete();

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(closeCalls, 1);
    });

    test('bounds cleanup time before closing', () async {
      var closeCalls = 0;
      final coordinator = WindowCloseCoordinator(
        cleanupTimeout: const Duration(milliseconds: 1),
      );

      final closed = await coordinator.requestClose(
        isCritical: false,
        cleanup: () => Completer<void>().future,
        closeWindow: () async {
          closeCalls++;
        },
      );

      expect(closed, isTrue);
      expect(closeCalls, 1);
    });
  });
}
