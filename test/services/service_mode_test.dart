import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

/// Service mode is what carries usb0 across the reboot into the newly
/// installed image. Nothing on the laptop runs on the far side of that
/// reboot, so what these two scripts say is the whole difference between a
/// board that answers afterwards and one that does not.
void main() {
  /// The scripts address /data directly, which is right on a scooter and
  /// unusable here. Pointing them at a temp directory keeps the logic under
  /// test and the filesystem out of it.
  String rehome(String script, String dir) =>
      script.replaceAll('/data/', '$dir/');

  Future<ProcessResult> runScript(
    String body,
    String dir, {
    Map<String, String>? environment,
  }) async {
    final file = File('$dir/script.sh');
    await file.writeAsString(body);
    return Process.run('sh', [file.path], environment: environment);
  }

  group('arming', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('service-mode-arm-');
    });
    tearDown(() => dir.delete(recursive: true));

    test('it is valid shell', () async {
      final file = File('${dir.path}/arm.sh');
      await file.writeAsString(SshService.serviceModeArmCommand);
      final syntax = await Process.run('sh', ['-n', file.path]);
      expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
    });

    test('it leaves the JSON settings-service reads back on boot', () async {
      final result = await runScript(
        rehome(SshService.serviceModeArmCommand, dir.path),
        dir.path,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());

      final written = File('${dir.path}/service-mode.json');
      expect(written.existsSync(), isTrue);

      // The shape is settings-service's overlayPersisted struct. A file it
      // cannot unmarshal reads as inactive, so a typo here is a silent
      // no-arm rather than an error anyone would see.
      final decoded =
          jsonDecode(await written.readAsString()) as Map<String, dynamic>;
      expect(decoded['active'], isTrue);
      expect(decoded['name'], 'service');
    });

    test('it writes through a temporary file and does not leave it', () async {
      final script = rehome(SshService.serviceModeArmCommand, dir.path);
      expect(script, contains('mv -f'),
          reason: 'a half-written file would read as no service mode at all');

      final result = await runScript(script, dir.path);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(File('${dir.path}/.service-mode.json.installer').existsSync(),
          isFalse);
    });

    test('the path the installer names is the one settings-service uses', () {
      expect(SshService.serviceModeStatePath, '/data/service-mode.json');
      expect(SshService.serviceModeArmCommand,
          contains(SshService.serviceModeStatePath));
    });
  });

  group('finish handover', () {
    late Directory dir;
    late String log;

    /// Stubs for the three commands the handover calls, so the order it calls
    /// them in can be asserted without a scooter. `sleep` is stubbed to
    /// nothing: the real one would add five seconds per run for no coverage.
    Future<void> stubBin(String redisCliBody) async {
      final bin = Directory('${dir.path}/bin');
      await bin.create();
      for (final entry in {
        'redis-cli': redisCliBody,
        'lsc': r'''#!/bin/sh
echo "lsc $*" >> "$LOG"
''',
        'sleep': '#!/bin/sh\nexit 0\n',
      }.entries) {
        final f = File('${bin.path}/${entry.key}');
        await f.writeAsString(entry.value);
        await Process.run('chmod', ['+x', f.path]);
      }
    }

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('service-mode-finish-');
      log = '${dir.path}/calls.log';
    });
    tearDown(() => dir.delete(recursive: true));

    test('it is valid shell', () async {
      final file = File('${dir.path}/finish.sh');
      await file.writeAsString(SshService.finishHandoverScript);
      final syntax = await Process.run('sh', ['-n', file.path]);
      expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
    });

    test('it waits for the clear before touching the policy', () async {
      // settings-service consumes clear:service off a list, so it lands some
      // time after the push. While the overlay is still up it treats a write
      // of anything else to an overlaid key as a user edit and re-asserts its
      // own value, so a policy write that jumped the queue would pin
      // always-on for the rest of the boot.
      await stubBin(r'''#!/bin/sh
echo "redis-cli $*" >> "$LOG"
case "$*" in
  *"hget settings dashboard.service-mode-active"*)
    n=$(cat "$STATE" 2>/dev/null || echo 0)
    n=$((n+1))
    echo "$n" > "$STATE"
    if [ "$n" -lt 3 ]; then echo true; else echo false; fi
    ;;
esac
''');
      final result = await runScript(
        rehome(SshService.finishHandoverScript, dir.path),
        dir.path,
        environment: {
          'PATH': '${dir.path}/bin:${Platform.environment['PATH']}',
          'LOG': log,
          'STATE': '${dir.path}/probe-count',
        },
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());

      final calls = await File(log).readAsLines();
      final push = calls.indexWhere((l) => l.contains('clear:service'));
      final policy = calls.indexWhere((l) => l.contains('usb0-policy auto'));
      final unlock = calls.indexWhere((l) => l.contains('scooter:state unlock'));

      expect(push, isNot(-1), reason: 'service mode is never cleared');
      expect(policy, greaterThan(push));
      expect(unlock, greaterThan(policy));

      // It actually waited rather than falling through: three probes, the
      // last of which answered false.
      expect(
        calls.where((l) => l.contains('service-mode-active')).length,
        3,
      );
    });

    test('an image with no service overlay is not made to wait', () async {
      // The status field is absent there, so the loop has to break on its
      // first pass and let `lsc set` do the work the way it always did. A
      // fifteen-second stall on every finish would be the cost of getting
      // this wrong.
      await stubBin(r'''#!/bin/sh
echo "redis-cli $*" >> "$LOG"
''');
      final result = await runScript(
        rehome(SshService.finishHandoverScript, dir.path),
        dir.path,
        environment: {
          'PATH': '${dir.path}/bin:${Platform.environment['PATH']}',
          'LOG': log,
        },
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());

      final calls = await File(log).readAsLines();
      expect(
        calls.where((l) => l.contains('service-mode-active')).length,
        1,
        reason: 'an absent status field should end the wait immediately',
      );
      expect(calls.any((l) => l.contains('usb0-policy auto')), isTrue);
      expect(calls.any((l) => l.contains('scooter:state unlock')), isTrue);
    });

    test('it removes the file rather than trusting the clear', () async {
      await stubBin(r'''#!/bin/sh
echo "redis-cli $*" >> "$LOG"
''');
      final armed = File('${dir.path}/service-mode.json');
      await armed.writeAsString('{"active":true,"name":"service"}');

      final result = await runScript(
        rehome(SshService.finishHandoverScript, dir.path),
        dir.path,
        environment: {
          'PATH': '${dir.path}/bin:${Platform.environment['PATH']}',
          'LOG': log,
        },
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(armed.existsSync(), isFalse,
          reason: 'a clear that never landed would come back on the next boot');
    });
  });

  group('interrupted-run disarm', () {
    test('it takes service mode with it and says so if it could not', () async {
      final command = SshService.interruptedInstallDisarmCommand;
      expect(command, contains('rm -f /data/service-mode.json'));
      expect(command, contains('service mode is still armed'));

      final dir = await Directory.systemTemp.createTemp('service-mode-disarm-');
      addTearDown(() => dir.delete(recursive: true));
      await Directory('${dir.path}/installer').create();
      final armed = File('${dir.path}/service-mode.json');
      await armed.writeAsString('{"active":true,"name":"service"}');

      final script = File('${dir.path}/disarm.sh');
      await script.writeAsString(rehome(command, dir.path));
      final result = await Process.run('sh', [script.path]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(armed.existsSync(), isFalse);
    });
  });
}
