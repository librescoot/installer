import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// dbc_ssh, wait_dbc_ssh and the dashboard power helpers, run for real against
/// stubbed binaries. Same approach as signal_helpers_test.dart, for the same
/// reason: this is the trampoline's only way to reach the DBC, on a board
/// nobody can watch, so it is exercised rather than grepped.
void main() {
  final device = File('assets/device.sh').readAsStringSync();

  late Directory root;
  late Directory bin;

  String calls() => File('${root.path}/calls').existsSync()
      ? File('${root.path}/calls').readAsStringSync()
      : '';

  Future<void> stub(String name, String body) async {
    final f = File('${bin.path}/$name');
    await f.writeAsString('#!/bin/sh\n$body\n');
    await Process.run('chmod', ['+x', f.path]);
  }

  /// Sources device.sh (with a stand-in log()) and runs [script] against it.
  Future<ProcessResult> run(String script) async {
    final f = File('${root.path}/case.sh');
    await f.writeAsString(
      'log() { echo "log: \$1" >> "\$CALLS"; }\n'
      '. ${root.path}/installer/scripts/device.sh\n$script\n',
    );
    return Process.run(
      'sh',
      [f.path],
      environment: {
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'CALLS': '${root.path}/calls',
      },
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('device-');
    bin = Directory('${root.path}/bin');
    await bin.create(recursive: true);
    await Directory('${root.path}/installer/scripts').create(recursive: true);
    await File('${root.path}/installer/scripts/device.sh').writeAsString(device);
    await stub('sleep', 'exit 0');
  });
  tearDown(() => root.delete(recursive: true));

  test('device.sh is valid POSIX sh', () async {
    final r = await Process.run('sh', ['-n', 'assets/device.sh']);
    expect(r.exitCode, 0, reason: r.stderr.toString());
  });

  group('one definition, everywhere', () {
    test('nothing in the trampoline template redefines a helper this file owns',
        () {
      // These used to be defined twice: once here, once inside the heredoc
      // that writes the dashboard phase. A second definition anywhere is that
      // drift, and it also wins over the sourced one, so the copy that gets
      // fixed is not the copy that runs.
      final owned = RegExp(r'^([a-z_][a-z0-9_]*)\(\)', multiLine: true)
          .allMatches(device)
          .map((m) => m.group(1)!)
          .toSet();
      expect(owned, contains('dbc_ssh'));
      expect(owned, contains('wait_dbc_ssh'));
      expect(owned, contains('dbc_power_set'));

      final body = File('assets/trampoline.sh.template').readAsStringSync();
      for (final name in owned) {
        expect(body, isNot(contains(RegExp('^ *$name\\(\\)', multiLine: true))),
            reason: 'assets/trampoline.sh.template redefines $name');
      }
    });

    test('the trampoline template sources this file', () {
      expect(File('assets/trampoline.sh.template').readAsStringSync(),
          contains('device.sh'),
          reason: 'the trampoline talks to the DBC without sourcing device.sh');
    });
  });

  group('dbc_ssh', () {
    test('succeeds on the first try', () async {
      await stub('ssh', 'echo "ssh \$*" >> "\$CALLS"; exit 0');
      final r = await run('dbc_ssh echo hi');
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(calls().split('\n').where((l) => l.startsWith('ssh')).length, 1);
    });

    test('retries three times, then gives up', () async {
      await stub('ssh', 'echo "ssh \$*" >> "\$CALLS"; exit 1');
      final r = await run('dbc_ssh echo hi');
      expect(r.exitCode, 1);
      expect(calls().split('\n').where((l) => l.startsWith('ssh')).length, 3);
      expect(calls(), contains('log:   ssh retry 1/3'));
    });
  });

  group('wait_dbc_ssh', () {
    test('needs three consecutive successes to call the DBC stable', () async {
      await stub('ssh', 'exit 0');
      final r = await run('wait_dbc_ssh 30');
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(calls(), contains('log:   DBC SSH stable after 0s'));
    });

    test('gives up after the timeout with no successful ssh', () async {
      await stub('ssh', 'exit 1');
      final r = await run('wait_dbc_ssh 3');
      expect(r.exitCode, 1);
    });
  });

  group('dbc_power_set', () {
    test('prefers lsc when it is on PATH', () async {
      await stub('lsc', 'echo "lsc \$*" >> "\$CALLS"; exit 0');
      final r = await run('dbc_power_set 1');
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(calls(), contains('lsc --redis-addr localhost:6379 dbc on'));
    });

    test('falls back to the GPIO when lsc fails, and reports it cannot claim it',
        () async {
      // No real /sys/class/gpio in a test sandbox, so the fallback itself
      // cannot succeed here; what matters is that the code takes that path
      // and says so, rather than silently doing nothing.
      await stub('lsc', 'exit 1');
      final r = await run('dbc_power_set 1');
      expect(r.exitCode, 1);
      expect(calls(), contains('log:   lsc dbc power failed, falling back to the GPIO'));
      expect(calls(),
          contains('log:   WARNING: could not claim the dashboard power GPIO'));
    });

    test('falls back to the GPIO when lsc is absent entirely', () async {
      final r = await run('dbc_power_set 0');
      expect(r.exitCode, 1);
      expect(calls(),
          contains('log:   WARNING: could not claim the dashboard power GPIO'));
    });
  });
}
