import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/dashboard_messages.dart';
import 'package:librescoot_installer/services/trampoline_service.dart';

/// Step 3's wait for the DBC. A DBC already parked in u-boot UMS is a USB
/// device that never answers a ping, so the wait has to alternate: ping in
/// gadget mode, peek at the bus in host mode, restore gadget, repeat. These
/// tests run the extracted function under sh with stubbed time, so a 300s
/// budget takes milliseconds.
void main() {
  late String source;

  setUpAll(() {
    source = File('assets/trampoline.sh.template').readAsStringSync();
  });

  String extractFunction() {
    final start = source.indexOf('dbc_ping_or_ums_wait() {');
    expect(start, isNot(-1), reason: 'dbc_ping_or_ums_wait not found');
    final end = source.indexOf('\n}\n', start) + 3;
    return source.substring(start, end);
  }

  group('wiring', () {
    test('step 3 waits through the alternating function', () {
      expect(source, contains('dbc_ping_or_ums_wait 300'));
    });

    test('probe_dbc_or_fail stays the verdict after the wait', () {
      // The wait only recognises UMS; the SDP check and the failure messages
      // live in the probe, and must still run when the budget expires.
      final wait = source.indexOf('dbc_ping_or_ums_wait 300');
      final probe = source.indexOf('probe_dbc_or_fail', wait);
      expect(probe, greaterThan(wait));
    });

    test('the function is valid POSIX shell', () async {
      final dir = await Directory.systemTemp.createTemp('ums-wait-');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/fn.sh');
      await f.writeAsString(extractFunction());
      final syntax = await Process.run('sh', ['-n', f.path]);
      expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
    });

    test('the rendered template is valid POSIX shell', () async {
      final rendered = TrampolineService.renderTemplate(
        source,
        upgradeMode: false,
        dbcImagePath: '/data/installer/dbc.sdimg.gz',
        dbcMenderPath: '/data/installer/dbc.mender',
        messages: DashboardMessages.english,
      );
      final dir = await Directory.systemTemp.createTemp('ums-wait-');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/trampoline.sh');
      await f.writeAsString(rendered);
      final syntax = await Process.run('sh', ['-n', f.path]);
      expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
    });
  });

  group('running it', () {
    late Directory root;
    late String calls;
    late String clock;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('ums-wait-run-');
      calls = '${root.path}/calls.log';
      clock = '${root.path}/clock';
      await File(clock).writeAsString('0\n');
      await File('${root.path}/fn.sh').writeAsString(extractFunction());
      // Time is a counter file: date reads it, sleep advances it. Everything
      // the function touches outside itself is a stub that logs its call.
      await File('${root.path}/driver.sh').writeAsString(r'''
#!/bin/sh
DBC_IP=192.168.7.2
date() { cat "$CLOCK_FILE"; }
sleep() { echo $(( $(cat "$CLOCK_FILE") + $1 )) > "$CLOCK_FILE"; }
log() { echo "log: $1" >> "$CALLS"; }
rmmod() { :; }
role_write() { echo "role_write $1" >> "$CALLS"; }
restore_gadget() { echo "restore_gadget" >> "$CALLS"; [ "$RESTORE_OK" != "no" ]; }
ping() { echo "ping $(cat "$CLOCK_FILE")" >> "$CALLS"; [ "$(cat "$CLOCK_FILE")" -ge "$PING_UP_AT" ]; }
lsusb() {
  echo "lsusb $(cat "$CLOCK_FILE")" >> "$CALLS"
  if [ "$(cat "$CLOCK_FILE")" -ge "$UMS_ON_BUS_AT" ]; then
    echo "Bus 001 Device 002: ID 0525:a4a5 Netchip Technology, Inc. Linux-USB File-backed Storage Gadget"
  fi
}
. "$FN_FILE"
dbc_ping_or_ums_wait "$BUDGET"
echo "rc=$? pinged=${DBC_PINGED:-no} ums=${DBC_ALREADY_UMS:-no} elapsed=$PING_ELAPSED"
''');
    });
    tearDown(() => root.delete(recursive: true));

    Future<String> run({
      int budget = 300,
      int pingUpAt = 999999,
      int umsOnBusAt = 999999,
      bool restoreOk = true,
    }) async {
      final result = await Process.run('sh', [
        '${root.path}/driver.sh'
      ], environment: {
        'CLOCK_FILE': clock,
        'CALLS': calls,
        'FN_FILE': '${root.path}/fn.sh',
        'BUDGET': '$budget',
        'PING_UP_AT': '$pingUpAt',
        'UMS_ON_BUS_AT': '$umsOnBusAt',
        'RESTORE_OK': restoreOk ? 'yes' : 'no',
        'PATH': Platform.environment['PATH']!,
      });
      expect(result.exitCode, 0, reason: result.stderr.toString());
      return result.stdout.toString().trim();
    }

    Future<List<String>> callLog() async =>
        File(calls).existsSync() ? File(calls).readAsLines() : <String>[];

    Future<int> virtualNow() async =>
        int.parse((await File(clock).readAsString()).trim());

    test('a DBC already in UMS is found on the first peek', () async {
      final out = await run(umsOnBusAt: 0);
      expect(out, contains('rc=0'));
      expect(out, contains('ums=yes'));
      expect(out, contains('pinged=no'));
      expect(await virtualNow(), lessThan(60),
          reason: 'the whole point: under a minute, not the whole budget');
      final log = await callLog();
      // The first stretch is pings, so a normally-booting DBC is never hit
      // with a role flip before it had a chance to answer.
      final firstPing = log.indexWhere((l) => l.startsWith('ping'));
      final firstFlip = log.indexWhere((l) => l == 'role_write host');
      expect(firstPing, greaterThanOrEqualTo(0));
      expect(firstFlip, greaterThan(firstPing));
      // Host mode is kept for step 5: no gadget restore after the find.
      expect(log.skip(firstFlip), isNot(contains('restore_gadget')));
    });

    test('with nothing on the bus it alternates until the budget is gone',
        () async {
      final out = await run(budget: 120);
      expect(out, contains('rc=1'));
      expect(out, contains('pinged=no'));
      expect(out, contains('ums=no'));
      final log = await callLog();
      final flips = log.where((l) => l == 'role_write host').length;
      final restores = log.where((l) => l == 'restore_gadget').length;
      expect(flips, greaterThanOrEqualTo(2), reason: 'no alternation happened');
      expect(restores, flips,
          reason: 'every peek must give gadget mode back');
      // Pings resume between peeks: each restore_gadget is followed by a ping
      // before the next flip.
      for (var i = 0; i < log.length; i++) {
        if (log[i] != 'restore_gadget') continue;
        final tail = log.skip(i + 1).toList();
        final nextFlip = tail.indexOf('role_write host');
        if (nextFlip == -1) continue;
        expect(
          tail.take(nextFlip).any((l) => l.startsWith('ping')),
          isTrue,
          reason: 'a peek was not followed by a ping stretch',
        );
      }
    });

    test('a slow-booting DBC still gets its ping window', () async {
      final out = await run(pingUpAt: 120);
      expect(out, contains('rc=0'));
      expect(out, contains('pinged=yes'));
      expect(out, contains('ums=no'));
      final log = await callLog();
      expect(log.where((l) => l == 'role_write host').length,
          greaterThanOrEqualTo(2),
          reason: 'the peeks ran while the DBC was still booting');
    });

    test('a failed gadget restore ends the wait instead of looping blind',
        () async {
      final out = await run(restoreOk: false);
      expect(out, contains('rc=1'));
      final log = await callLog();
      expect(log.where((l) => l == 'role_write host').length, 1,
          reason: 'no point peeking again when pinging cannot resume');
      expect(await virtualNow(), lessThan(60),
          reason: 'bails to the probe rather than burning the budget');
    });
  });
}
