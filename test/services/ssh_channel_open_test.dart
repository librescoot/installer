import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

void main() {
  group('a channel the far end never confirms', () {
    test(
      'a reconnect from an older generation cannot become authoritative',
      () {
        expect(
          SshService.connectionAttemptIsCurrent(
            attemptGeneration: 4,
            currentGeneration: 5,
          ),
          isFalse,
        );
        expect(
          SshService.connectionAttemptIsCurrent(
            attemptGeneration: 5,
            currentGeneration: 5,
          ),
          isTrue,
        );
      },
    );

    test('counts as a lost connection, not a failed command', () {
      expect(
        SshService.isLostConnection(
          const SshChannelOpenTimeout('command', Duration(seconds: 30)),
        ),
        isTrue,
      );
      expect(
        SshService.isLostConnection(
          const SocketException('connection reset by peer'),
        ),
        isTrue,
      );
      expect(
        SshService.isLostConnection(Exception('Command failed (exit 1): ls')),
        isFalse,
      );
    });

    test('does not read as a board that rebooted', () {
      final text = const SshChannelOpenTimeout(
        'command',
        Duration(seconds: 30),
      ).toString().toLowerCase();

      for (final marker in [
        'connection reset',
        'broken pipe',
        'socket',
        'eof',
        'closed',
      ]) {
        expect(text, isNot(contains(marker)), reason: 'matched "$marker"');
      }
    });

    test('drops the session so the next command reconnects', () async {
      var invalidations = 0;
      var reconnects = 0;
      var executions = 0;

      final result = await SshService.executeWithReplayPolicy<String>(
        execute: () async {
          executions++;
          if (executions == 1) {
            throw const SshChannelOpenTimeout('command', Duration(seconds: 30));
          }
          return 'ran on the new session';
        },
        reconnect: () async => reconnects++,
        invalidateConnection: () => invalidations++,
        isDisconnect: SshService.isLostConnection,
        replayOnDisconnect: true,
      );

      expect(result, 'ran on the new session');
      expect(invalidations, 1);
      expect(reconnects, 1);
    });
  });
}
