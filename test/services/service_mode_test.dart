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

  group('interrupted-run disarm', () {
    test('it leaves service mode alone, because the retry needs it', () async {
      // This runs at the start of a retry, on a board whose last install did
      // not finish. Keycards are paired by then, so ending service mode puts
      // usb0-policy back to auto, the gate closes, and the retry is plugged
      // into a board that does not answer.
      final command = SshService.interruptedInstallDisarmCommand;
      expect(command, isNot(contains('rm -f /data/service-mode.json')));
      expect(command, isNot(contains('clear:service')));

      final dir = await Directory.systemTemp.createTemp('service-mode-disarm-');
      addTearDown(() => dir.delete(recursive: true));
      await Directory('${dir.path}/installer').create();
      final armed = File('${dir.path}/service-mode.json');
      await armed.writeAsString('{"active":true,"name":"service"}');

      final script = File('${dir.path}/disarm.sh');
      await script.writeAsString(rehome(command, dir.path));
      final result = await Process.run('sh', [script.path]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(armed.existsSync(), isTrue,
          reason: 'the board has to still be reachable when the retry starts');
    });
  });
}
