import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/serial_polling_loop.dart';

void main() {
  test('a slow poll never overlaps the next interval', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondStarted = Completer<void>();
    var calls = 0;
    var inFlight = 0;
    var maximumInFlight = 0;
    final loop = SerialPollingLoop();

    loop.start(
      interval: const Duration(milliseconds: 1),
      immediately: true,
      poll: (_) async {
        calls++;
        inFlight++;
        maximumInFlight = inFlight > maximumInFlight
            ? inFlight
            : maximumInFlight;
        if (calls == 1) {
          firstStarted.complete();
          await releaseFirst.future;
        } else {
          secondStarted.complete();
        }
        inFlight--;
      },
    );

    await firstStarted.future;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls, 1);
    expect(maximumInFlight, 1);

    releaseFirst.complete();
    await secondStarted.future;
    await loop.stop();
    expect(maximumInFlight, 1);
  });

  test('stop invalidates stale results and awaits the active poll', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var applied = false;
    var stopped = false;
    final loop = SerialPollingLoop();

    loop.start(
      interval: const Duration(milliseconds: 1),
      immediately: true,
      poll: (generation) async {
        started.complete();
        await release.future;
        if (generation.isCurrent) applied = true;
      },
    );

    await started.future;
    final stop = loop.stop().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);

    release.complete();
    await stop;
    expect(applied, isFalse);
    expect(loop.isRunning, isFalse);
  });
}
