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
    await File(
      '${root.path}/installer/scripts/device.sh',
    ).writeAsString(device);
    await stub('sleep', 'exit 0');
  });
  tearDown(() => root.delete(recursive: true));

  test('device.sh is valid POSIX sh', () async {
    final r = await Process.run('sh', ['-n', 'assets/device.sh']);
    expect(r.exitCode, 0, reason: r.stderr.toString());
  });

  group('one definition, everywhere', () {
    test(
      'nothing in the trampoline template redefines a helper this file owns',
      () {
        // These used to be defined twice: once here, once inside the heredoc
        // that writes the dashboard phase. A second definition anywhere is that
        // drift, and it also wins over the sourced one, so the copy that gets
        // fixed is not the copy that runs.
        final owned = RegExp(
          r'^([a-z_][a-z0-9_]*)\(\)',
          multiLine: true,
        ).allMatches(device).map((m) => m.group(1)!).toSet();
        expect(owned, contains('dbc_ssh'));
        expect(owned, contains('wait_dbc_ssh'));
        expect(owned, contains('dbc_power_set'));

        final body = File('assets/trampoline.sh.template').readAsStringSync();
        for (final name in owned) {
          expect(
            body,
            isNot(contains(RegExp('^ *$name\\(\\)', multiLine: true))),
            reason: 'assets/trampoline.sh.template redefines $name',
          );
        }
      },
    );

    test('the trampoline template sources this file', () {
      expect(
        File('assets/trampoline.sh.template').readAsStringSync(),
        contains('device.sh'),
        reason: 'the trampoline talks to the DBC without sourcing device.sh',
      );
    });
  });

  test(
    'failed power control is not accepted because DBC is unpingable',
    () async {
      await stub('ping', 'exit 1');
      final r = await run('dbc_power_off() { return 1; }; dbc_power_off_wait');
      expect(r.exitCode, 1);
    },
  );

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

  group('USB host handoff', () {
    test('recovers a rapid laptop-to-DBC swap with no UDC gap', () async {
      final state = File('${root.path}/udc-state')
        ..writeAsStringSync('configured\n');
      final rebound = '${root.path}/rebound';
      await stub('ping', '[ -e "$rebound" ]');
      await stub('rmmod', 'echo "rmmod \$*" >> "\$CALLS"');
      await stub('modprobe', '''
echo "modprobe \$*" >> "\$CALLS"
touch "$rebound"
''');

      final r = await run('''
USB_HANDOFF_UDC_STATE="${state.path}"
USB_HANDOFF_REBIND_AFTER=2
USB_HANDOFF_REBIND_RETRY=5
USB_HANDOFF_REBIND_GRACE=1
usb0_up() { echo usb0_up >> "\$CALLS"; }
wait_for_laptop_disconnect
''');

      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(calls(), contains('UDC stayed configured'));
      expect(calls(), contains('rmmod g_ether'));
      expect(calls(), contains('modprobe g_ether'));
      expect(calls(), contains('log: DBC USB peer detected'));
    });

    test('accepts a sustained unconfigured UDC without rebinding', () async {
      final state = File('${root.path}/udc-state')
        ..writeAsStringSync('not attached\n');
      await stub('ping', 'exit 1');
      await stub('rmmod', 'echo "rmmod \$*" >> "\$CALLS"');

      final r = await run('''
USB_HANDOFF_UDC_STATE="${state.path}"
USB_HANDOFF_GONE_NEEDED=3
wait_for_laptop_disconnect
''');

      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(calls(), contains('Laptop disconnected (debounced)'));
      expect(calls(), isNot(contains('rmmod g_ether')));
    });
  });

  group('forced lifecycle power-off', () {
    test('queues force and requires vehicle-service acknowledgement', () async {
      await stub('redis-cli', '''
echo "redis-cli \$*" >> "\$CALLS"
case "\$*" in
  *"lpush scooter:hardware dashboard:off:force"*) echo 1 ;;
  *"hget vehicle dashboard:power"*) echo off ;;
esac
''');
      await stub('ping', 'exit 1');

      final r = await run('dbc_power_off_wait_force');

      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(calls(), contains('lpush scooter:hardware dashboard:off:force'));
      expect(calls(), contains('hget vehicle dashboard:power'));
      expect(
        calls(),
        contains('Dashboard power: off (forced and acknowledged)'),
      );
    });

    test('fails when forced power-off is never acknowledged', () async {
      await stub('redis-cli', '''
case "\$*" in
  *"lpush scooter:hardware dashboard:off:force"*) echo 1 ;;
  *"hget vehicle dashboard:power"*) echo on ;;
esac
''');

      final r = await run('dbc_power_off_force');

      expect(r.exitCode, 1);
      expect(
        calls(),
        contains('forced dashboard power-off was not acknowledged'),
      );
    });
  });

  for (final failedWrite in [false, true]) {
    test(
      'bootstrap GPIO write and readback: write failure=$failedWrite',
      () async {
        final gpio = Directory('${root.path}/gpio/gpio50')
          ..createSync(recursive: true);
        File('${gpio.path}/direction').writeAsStringSync('out\n');
        if (failedWrite) {
          Directory('${gpio.path}/value').createSync();
        } else {
          File('${gpio.path}/value').writeAsStringSync('1\n');
        }
        File('${root.path}/installer/scripts/device.sh').writeAsStringSync(
          device.replaceAll('/sys/class/gpio', '${root.path}/gpio'),
        );
        await stub('ping', 'exit 1');
        final result = await run(
          'dbc_control_check() { return 0; }; dbc_power_off_wait',
        );
        expect(
          result.exitCode,
          failedWrite ? 1 : 0,
          reason: result.stderr.toString(),
        );
        if (!failedWrite) {
          expect(File('${gpio.path}/value').readAsStringSync().trim(), '0');
        }
      },
    );
  }

  test('UMS transport must disappear even after GPIO request is low', () async {
    final transport = File('${root.path}/ums')..writeAsStringSync('present');
    File('${root.path}/installer/scripts/device.sh').writeAsStringSync(
      device.replaceAll('[ -b "\$DBC_DEV" ]', '[ -e "\$DBC_DEV" ]'),
    );
    await stub('ping', 'exit 1');
    final result = await run(
      'DBC_DEV="${transport.path}"; dbc_power_off() { return 0; }; dbc_power_off_wait 2',
    );
    expect(result.exitCode, 1);
  });

  test('DBC power-on wait counts ping time against its deadline', () async {
    final clock = File('${root.path}/clock')..writeAsStringSync('0\n');
    await stub('date', 'cat "${clock.path}"');
    await stub('ping', '''
n=\$(cat "${clock.path}")
echo \$((n + 3)) > "${clock.path}"
echo ping >> "\$CALLS"
exit 1
''');
    await stub('sleep', '''
n=\$(cat "${clock.path}")
echo \$((n + \$1)) > "${clock.path}"
''');

    final r = await run('dbc_power_on() { return 1; }; dbc_power_on_wait 5');

    expect(r.exitCode, 1);
    expect(calls().split('\n').where((line) => line == 'ping').length, 1);
    expect(clock.readAsStringSync().trim(), '5');
  });

  group('dbc_power_set', () {
    test('prefers lsc when it is on PATH', () async {
      await stub('lsc', 'echo "lsc \$*" >> "\$CALLS"; exit 0');
      final r = await run('dbc_power_set 1');
      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(calls(), contains('lsc --redis-addr localhost:6379 dbc on'));
    });

    test('does not bypass service ownership when lsc fails', () async {
      await stub('lsc', 'exit 1');
      final r = await run('dbc_power_set 1');
      expect(r.exitCode, 1);
      expect(
        calls(),
        contains('log:   lsc dbc power failed; refusing GPIO fallback'),
      );
      expect(
        calls(),
        isNot(contains('could not claim the dashboard power GPIO')),
      );
    });

    test('absent lsc is not permission to control GPIO', () async {
      final r = await run('dbc_power_set 0');
      expect(r.exitCode, 1);
      expect(
        calls(),
        contains(
          'log:   WARNING: refusing GPIO power control without bootstrap ownership',
        ),
      );
    });
  });
}
