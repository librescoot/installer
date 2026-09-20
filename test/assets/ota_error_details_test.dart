import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final redisAvailable =
      !Platform.isWindows &&
      Process.runSync('sh', [
            '-c',
            'command -v redis-server && command -v redis-cli',
          ]).exitCode ==
          0;
  final skipReason = redisAvailable ? false : 'redis-server is not installed';

  late Directory root;
  late String socket;
  Process? server;

  ProcessResult redis(List<String> arguments) =>
      Process.runSync('redis-cli', ['-s', socket, ...arguments]);

  void command(List<String> arguments) {
    final result = redis(arguments);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  }

  void stream(Map<String, String> fields) {
    command([
      'XADD',
      'ota:errors',
      '*',
      for (final field in fields.entries) ...[field.key, field.value],
    ]);
  }

  String readErrors([String component = 'dbc']) {
    final result = Process.runSync(
      'sh',
      ['assets/ota-error-details.sh', component],
      environment: {'REDIS_SOCKET': socket},
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    return result.stdout.toString().trim();
  }

  setUpAll(() async {
    if (!redisAvailable) return;
    root = Directory.systemTemp.createTempSync('ota_error_details_');
    socket = '${root.path}/redis.sock';
    server = await Process.start('redis-server', [
      '--port',
      '0',
      '--unixsocket',
      socket,
      '--save',
      '',
      '--appendonly',
      'no',
    ]);
    unawaited(server!.stdout.drain<void>());
    unawaited(server!.stderr.drain<void>());

    for (var attempt = 0; attempt < 100; attempt++) {
      if (File(socket).existsSync() && redis(['PING']).exitCode == 0) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('redis-server did not create $socket');
  });

  setUp(() {
    if (redisAvailable) command(['FLUSHALL']);
  });

  tearDownAll(() async {
    if (!redisAvailable) return;
    redis(['SHUTDOWN', 'NOSAVE']);
    try {
      await server!.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      server!.kill();
    }
    root.deleteSync(recursive: true);
  });

  test('reads only DBC errors after the latest DBC reset', () {
    stream({
      'event': 'error',
      'component': 'dbc',
      'code': 'old-failure',
      'message': 'from an earlier operation',
    });
    stream({'event': 'reset', 'component': 'dbc'});
    stream({
      'event': 'error',
      'component': 'mdb',
      'code': 'mdb-failure',
      'message': 'not a dashboard error',
    });
    stream({
      'event': 'error',
      'component': 'dbc',
      'code': 'delta-failed',
      'message': 'delta checksum mismatch',
    });
    stream({'event': 'reset', 'component': 'mdb'});
    stream({
      'event': 'error',
      'component': 'dbc',
      'code': 'download-failed',
      'message': 'full image timed out',
    });

    expect(
      readErrors(),
      'delta-failed: delta checksum mismatch\n'
      'download-failed: full image timed out',
    );
  }, skip: skipReason);

  test('preserves repeated identical stream errors', () {
    stream({'event': 'reset', 'component': 'dbc'});
    for (var occurrence = 0; occurrence < 2; occurrence++) {
      stream({
        'event': 'error',
        'component': 'dbc',
        'code': 'reboot-failed',
        'message': 'reboot unavailable',
      });
    }

    expect(
      readErrors(),
      'reboot-failed: reboot unavailable\n'
      'reboot-failed: reboot unavailable',
    );
  }, skip: skipReason);

  test('prefers stream history over the compatibility hash', () {
    command([
      'HSET',
      'ota',
      'error:dbc',
      'hash-code',
      'error-message:dbc',
      'hash message',
    ]);
    stream({'event': 'reset', 'component': 'dbc'});
    stream({
      'event': 'error',
      'component': 'dbc',
      'code': 'stream-code',
      'message': 'stream message',
    });

    expect(readErrors(), 'stream-code: stream message');
  }, skip: skipReason);

  test('falls back to legacy hash fields when the stream is missing', () {
    command([
      'HSET',
      'ota',
      'error:dbc',
      'install-failed',
      'error-message:dbc',
      'Mender exited with status 42',
    ]);

    expect(readErrors(), 'install-failed: Mender exited with status 42');
  }, skip: skipReason);

  test('ignores malformed stream data and uses the hash fallback', () {
    command(['SET', 'ota:errors', 'not a stream']);
    command([
      'HSET',
      'ota',
      'error:dbc',
      'state-read-failed',
      'error-message:dbc',
      'could not read Mender state',
    ]);

    expect(readErrors(), 'state-read-failed: could not read Mender state');
  }, skip: skipReason);
}
