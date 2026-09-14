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

  group('every remote wait is bounded', () {
    final source = File('lib/services/ssh_service.dart').readAsStringSync();

    test('no channel is opened outside the bounded helpers', () {
      final raw = RegExp(r'\.execute\(|\.sftp\(\)')
          .allMatches(source)
          .map(
            (m) => source
                .substring(m.start, source.indexOf(';', m.start))
                .replaceAll('\n', ' '),
          )
          .where((statement) => !statement.contains('.timeout('))
          .toList();

      expect(raw, isEmpty, reason: 'open these through _openSession/_openSftp');
    });

    test('the silent reconnect bounds its handshake', () {
      final start = source.indexOf('Future<void> _doReconnect()');
      final block = source.substring(start, source.indexOf('\n  }', start));
      expect(block, contains('authenticated.timeout(connectionTimeout)'));
    });

    test('the SFTP probe finishes closing before the next channel opens', () {
      final start = source.indexOf("debugPrint('SSH: SFTP available')");
      final block = source.substring(start, start + 900);
      expect(block, contains('await sftp.close()'));
    });

    test('no close waits on a far end that may never answer', () {
      for (final m in RegExp(
        r'await sftp\.close\(\)[^;]*;',
      ).allMatches(source)) {
        expect(m.group(0), contains('.timeout('), reason: m.group(0));
      }
    });
  });

  group('the keepalive has a verdict', () {
    final source = File('lib/services/ssh_service.dart').readAsStringSync();

    test("dartssh2's own is switched off, not left to run alongside", () {
      expect(source, isNot(contains('keepAliveInterval: const Duration')));
      expect('keepAliveInterval: null'.allMatches(source).length, 2);
    });

    test('unanswered pings end the session', () {
      final start = source.indexOf('void _startLiveness(');
      final block = source.substring(
        start,
        source.indexOf('\n  void _stopLiveness', start),
      );
      expect(block, contains('client.ping().timeout(livenessInterval)'));
      expect(block, contains('misses < livenessFailureLimit'));
      expect(block, contains('var inFlight = false;'));
      expect(block, contains('_invalidateClient(client)'));
      expect(block, contains('identical(_client, client)'));
    });

    test('each liveness generation keeps its own state', () {
      expect(
        blockFor(source, 'void _startLiveness(', 'void _stopLiveness'),
        contains('var misses = 0;'),
      );
      expect(source, isNot(contains('_livenessMisses')));
      expect(source, isNot(contains('_livenessInFlight')));
    });

    test('it is torn down with the client it watches', () {
      for (final fn in [
        'void _invalidateClient([SSHClient? expected])',
        'void disconnect()',
      ]) {
        final start = source.indexOf(fn);
        expect(
          source.substring(start, start + 200),
          contains('_stopLiveness()'),
          reason: fn,
        );
      }
    });

    test('command and streaming timeouts invalidate their owning client', () {
      final command = blockFor(
        source,
        'Future<String> _runCommandOnce(',
        '/// Run [command], handing stdout',
      );
      final streaming = blockFor(
        source,
        'Future<({int exitCode, String stdout, String stderr})> runStreaming(',
        '/// True when the board carries',
      );
      expect(command, contains('_invalidateClient(client)'));
      expect(streaming, contains('_invalidateClient(client)'));
      expect(source, contains('operationClient = _requireClient'));
      expect(source, contains('() => _invalidateClient(operationClient)'));
    });
  });
}

String blockFor(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start);
  return source.substring(start, end);
}
