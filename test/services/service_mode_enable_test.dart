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

}
