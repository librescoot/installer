import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/usb_detector.dart';

void main() {
  group('USB probes cannot pile up behind a device that stopped answering', () {
    test(
      'a probe that will not return is killed and reads as failed',
      () async {
        final started = DateTime.now();
        final r = await runBounded('sh', [
          '-c',
          'sleep 30',
        ], timeout: const Duration(milliseconds: 200));
        expect(r.exitCode, -1);
        expect(r.stderr, 'timed out');
        expect(
          DateTime.now().difference(started),
          lessThan(const Duration(seconds: 5)),
          reason: 'it gave up on the child rather than waiting for it',
        );
      },
    );

    test(
      'a missing binary throws rather than coming back as a failure',
      () async {
        await expectLater(
          runBounded('definitely-not-a-real-binary-xyz', const []),
          throwsA(isA<ProcessException>()),
        );
      },
    );

    test('a child that exits on its own is reported as it exited', () async {
      final r = await runBounded('sh', ['-c', 'echo out; exit 7']);
      expect(r.exitCode, 7);
      expect(r.stdout.toString().trim(), 'out');
    });

    test('environment variables reach the child', () async {
      final r = await runBounded(
        'sh',
        ['-c', r'printf %s "$BOUNDED_TEST"'],
        environment: const {'BOUNDED_TEST': 'present'},
      );
      expect(r.exitCode, 0);
      expect(r.stdout, 'present');
    });
  });

  group('a slow machine is not a missing device', () {
    test(
      'an 11-second probe fits the default bound on a scaled clock',
      () async {
        // Scale the timeout and subprocess delay equally; a 10-second default
        // must still kill the probe, while the 30-second bound lets it answer.
        final bounds = <Duration>[];
        final r = await runZoned(
          () => runBounded('sh', ['-c', 'sleep 1.1; echo slow-but-alive']),
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              bounds.add(duration);
              return parent.createTimer(zone, duration ~/ 10, callback);
            },
          ),
        );
        expect(bounds, contains(const Duration(seconds: 30)));
        expect(r.exitCode, 0, reason: r.stderr.toString());
        expect(r.stdout.toString().trim(), 'slow-but-alive');
      },
    );
  });
}
