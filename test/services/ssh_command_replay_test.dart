import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

void main() {
  test('ambiguous disconnect does not replay by default', () async {
    var executions = 0;
    var reconnects = 0;
    var invalidations = 0;

    await expectLater(
      SshService.executeWithReplayPolicy<void>(
        execute: () async {
          executions++;
          throw const SocketException('connection reset after execution');
        },
        reconnect: () async {
          reconnects++;
        },
        invalidateConnection: () => invalidations++,
        isDisconnect: (error) => error is SocketException,
      ),
      throwsA(isA<SocketException>()),
    );

    expect(executions, 1);
    expect(reconnects, 0);
    expect(invalidations, 1);
  });

  test('an explicitly replay-safe command reconnects once', () async {
    var executions = 0;
    var reconnects = 0;
    var invalidations = 0;

    final result = await SshService.executeWithReplayPolicy<String>(
      execute: () async {
        executions++;
        if (executions == 1) {
          throw const SocketException('connection reset after execution');
        }
        return 'acknowledged';
      },
      reconnect: () async {
        reconnects++;
      },
      invalidateConnection: () => invalidations++,
      isDisconnect: (error) => error is SocketException,
      replayOnDisconnect: true,
    );

    expect(result, 'acknowledged');
    expect(executions, 2);
    expect(reconnects, 1);
    expect(invalidations, 1);
  });

  test('queue retries use a stable SET NX operation key', () {
    final first = SshService.buildDeduplicatedRedisLpushCommand(
      key: 'scooter:bluetooth',
      value: 'advertising-restart-no-whitelisting',
      operationId: 'run-42',
    );
    final retry = SshService.buildDeduplicatedRedisLpushCommand(
      key: 'scooter:bluetooth',
      value: 'advertising-restart-no-whitelisting',
      operationId: 'run-42',
    );

    expect(retry, first);
    expect(first, contains('SET'));
    expect(first, contains('NX'));
    expect(first, contains('LPUSH'));
    expect(first, contains('librescoot-installer:queue-op:run-42'));
  });

  test('reboot explicitly treats a disconnect as acknowledgement', () {
    final source = File('lib/services/ssh_service.dart').readAsStringSync();
    final start = source.indexOf('Future<void> reboot()');
    final end = source.indexOf('bool _looksLikeDisconnect', start);
    final block = source.substring(start, end);

    expect(block, contains('runCommand(cmd, replayOnDisconnect: false)'));
    expect(block, contains('reboot likely triggered (connection dropped)'));
  });

  test('successful legacy completion records suppress recovery', () {
    final source = File('lib/services/ssh_service.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> lastInstallSucceeded()');
    final end = source.indexOf('Future<bool> installPhasesActive()', start);
    final block = source.substring(start, end);

    expect(block, contains(r'$installerLastInstall'));
    expect(block, contains(r'$legacyLastInstall'));
    expect(block, contains("== 'result: success'"));
  });
}
