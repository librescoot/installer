import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// Service mode is armed at connect, on a board that may not have it. What
/// these cover is the probe telling those two cases apart, and the finish not
/// undoing the overlay's work with the schema defaults it used to write.
void main() {
  group('enabling at connect', () {
    late Directory dir;
    late String log;

    Future<void> stubRedis(String body) async {
      final bin = Directory('${dir.path}/bin');
      await bin.create();
      final redis = File('${bin.path}/redis-cli');
      await redis.writeAsString(body);
      // The wait is real seconds on a scooter and no coverage here.
      final sleeper = File('${bin.path}/sleep');
      await sleeper.writeAsString('#!/bin/sh\nexit 0\n');
      for (final f in [redis, sleeper]) {
        await Process.run('chmod', ['+x', f.path]);
      }
    }

    Future<ProcessResult> run() async {
      final file = File('${dir.path}/enable.sh');
      await file.writeAsString(SshService.serviceModeEnableCommand);
      return Process.run('sh', [file.path], environment: {
        'PATH': '${dir.path}/bin:${Platform.environment['PATH']}',
        'LOG': log,
        'STATE': '${dir.path}/probe-count',
      });
    }

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('sm-enable-');
      log = '${dir.path}/calls.log';
    });
    tearDown(() => dir.delete(recursive: true));

    test('it is valid shell', () async {
      final file = File('${dir.path}/syntax.sh');
      await file.writeAsString(SshService.serviceModeEnableCommand);
      final syntax = await Process.run('sh', ['-n', file.path]);
      expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
    });

    test('an absent status field answers in one read', () async {
      // The field carries a schema default, so a build with the overlay always
      // publishes it and one without never does. Answering from that alone is
      // what keeps stage 0 and stock boards, which have no settings-service at
      // all, from paying the confirmation wait on every connect.
      await stubRedis('#!/bin/sh\necho "redis-cli \$*" >> "\$LOG"\n');
      final result = await run();
      expect(result.stdout.toString().trim(), 'unsupported');

      final calls = await File(log).readAsLines();
      expect(calls.length, 1);
      expect(calls.any((l) => l.contains('apply:service')), isFalse,
          reason: 'nothing should be pushed at a board that cannot consume it');
    });

    test('a board already in service mode is left alone', () async {
      // It captured its base when it was turned on, and that base is the one
      // worth restoring. Applying again would capture the overlay's own values
      // and hand those back at the end.
      await stubRedis(r'''#!/bin/sh
echo "redis-cli $*" >> "$LOG"
case "$*" in *"hget settings dashboard.service-mode-active"*) echo true ;; esac
''');
      final result = await run();
      expect(result.stdout.toString().trim(), 'already-on');
      final calls = await File(log).readAsLines();
      expect(calls.any((l) => l.contains('apply:service')), isFalse);
    });

    test('it confirms from the published status, not from the push', () async {
      // apply:service is consumed off a list, so a push that succeeded says
      // nothing about whether anything was listening.
      await stubRedis(r'''#!/bin/sh
echo "redis-cli $*" >> "$LOG"
case "$*" in
  *"hget settings dashboard.service-mode-active"*)
    n=$(cat "$STATE" 2>/dev/null || echo 0)
    n=$((n+1))
    echo "$n" > "$STATE"
    if [ "$n" -ge 3 ]; then echo true; else echo false; fi
    ;;
esac
''');
      final result = await run();
      expect(result.stdout.toString().trim(), 'on');
      final calls = await File(log).readAsLines();
      expect(
          calls.any((l) => l.contains('lpush settings:overlay apply:service')),
          isTrue);
    });

    test('a push nothing consumes ends, rather than hanging', () async {
      await stubRedis(r'''#!/bin/sh
echo "redis-cli $*" >> "$LOG"
case "$*" in *"hget settings dashboard.service-mode-active"*) echo false ;; esac
''');
      final result = await run();
      expect(result.stdout.toString().trim(), 'timeout');
    });
  });

  group('the finish leaves configured values alone', () {
    test('the laptop finish skips the manual restore when the overlay is live',
        () {
      // _resetPersistedSettings has a last resort that writes the schema
      // defaults for the two parked keys. Against a live overlay,
      // settings-service reads those as a deliberate edit to an overlaid key,
      // moves its captured base to them, and hands the owner 900 and true at
      // the clear instead of whatever they had configured.
      final source =
          File('lib/screens/installer_screen.dart').readAsStringSync();
      final start = source.indexOf('Future<void> _onEnterFinish() async {');
      final end = source.indexOf('\n  /// Whether the device wrote', start);
      expect(start, isNot(-1));
      expect(end, isNot(-1));
      final finish = source
          .substring(start, end)
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      final guard = finish.indexOf('if (_serviceModeLive) {');
      expect(guard, isNot(-1), reason: 'the restore runs unconditionally');
      expect(finish.indexOf('_resetPersistedSettings()'), greaterThan(guard),
          reason: 'the restore has to sit in the else arm');
    });

    test('the trampoline guards the same last resort', () {
      final template = File('assets/trampoline.sh.template').readAsStringSync();
      final guard = template.indexOf(
          'hget settings dashboard.service-mode-active 2>/dev/null)" = true ]; then');
      final defaults =
          template.indexOf('lsc set scooter.auto-standby-seconds 900');
      expect(guard, isNot(-1),
          reason: 'the device finish writes the same two defaults');
      expect(defaults, greaterThan(guard));
    });

    test('the trampoline ends service mode before restoring the policy', () {
      // Without this a device-finished install hands the owner a scooter still
      // in service mode: no hibernation timer and no alarm, on every boot.
      final template = File('assets/trampoline.sh.template').readAsStringSync();
      final clear = template.indexOf('lpush settings:overlay clear:service');
      final removal = template.indexOf('rm -f /data/service-mode.json');
      final policy = template.indexOf('lsc set scooter.usb0-policy auto');
      expect(clear, isNot(-1), reason: 'the device finish never clears it');
      expect(policy, greaterThan(clear),
          reason: 'a policy write before the clear lands gets re-asserted');
      expect(removal, greaterThan(clear));
      expect(removal, lessThan(policy));
    });
  });
}
