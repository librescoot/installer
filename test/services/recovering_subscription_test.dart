import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/recovering_subscription.dart';

void main() {
  for (final failWithError in [false, true]) {
    test(
      'recovers after stream ${failWithError ? "error" : "closure"}',
      () async {
        final streams = <StreamController<String>>[];
        final recovered = Completer<void>();
        final events = <String>[];
        var refreshes = 0;
        var stops = 0;
        final subscription = RecoveringSubscription(
          retryDelay: Duration.zero,
          connect: () async {
            final stream = StreamController<String>();
            streams.add(stream);
            return (
              events: stream.stream,
              stop: () async {
                stops++;
              },
            );
          },
          onEvent: events.add,
          onConnected: () async {
            if (++refreshes == 2) recovered.complete();
          },
          onError: (_) {},
        );
        await subscription.start();
        if (failWithError) {
          streams.first.addError(StateError('SSH disconnected'));
        } else {
          await streams.first.close();
        }
        await recovered.future.timeout(const Duration(seconds: 2));
        streams.last.add('card-learned:123');
        await Future<void>.delayed(Duration.zero);
        expect(events, ['card-learned:123']);
        expect(refreshes, 2);
        expect(stops, 1);
        await subscription.stop();
        for (final stream in streams) {
          await stream.close();
        }
      },
    );
  }

  test('retries a failed connection', () async {
    final ready = Completer<void>();
    final stream = StreamController<String>();
    var attempts = 0;
    final subscription = RecoveringSubscription(
      retryDelay: Duration.zero,
      connect: () async {
        if (++attempts == 1) throw StateError('offline');
        return (events: stream.stream, stop: () async {});
      },
      onEvent: (_) {},
      onConnected: () async {
        ready.complete();
      },
      onError: (_) {},
    );
    await expectLater(subscription.start(), throwsStateError);
    await ready.future.timeout(const Duration(seconds: 2));
    expect(attempts, 2);
    await subscription.stop();
    await stream.close();
  });

  test(
    'serializes starts and closes an opening connection after stop',
    () async {
      final connection = Completer<EventConnection>();
      final stream = StreamController<String>.broadcast();
      var attempts = 0;
      var stops = 0;
      var refreshes = 0;
      final subscription = RecoveringSubscription(
        connect: () {
          attempts++;
          return connection.future;
        },
        onEvent: (_) {},
        onConnected: () async {
          refreshes++;
        },
        onError: (_) {},
      );
      final first = subscription.start();
      final second = subscription.start();
      final stopped = subscription.stop();
      connection.complete((
        events: stream.stream,
        stop: () async {
          stops++;
        },
      ));
      await Future.wait([first, second, stopped]);
      await subscription.start();
      expect(attempts, 1);
      expect(stops, 1);
      expect(refreshes, 0);
      await stream.close();
    },
  );

  test('leaving cancels a pending retry', () async {
    var attempts = 0;
    final subscription = RecoveringSubscription(
      retryDelay: Duration.zero,
      connect: () async {
        attempts++;
        throw StateError('offline');
      },
      onEvent: (_) {},
      onConnected: () async {},
      onError: (_) {},
    );
    await expectLater(subscription.start(), throwsStateError);
    await subscription.stop();
    await Future<void>.delayed(Duration.zero);
    expect(attempts, 1);
  });
}
