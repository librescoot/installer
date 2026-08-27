import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

void main() {
  test('disarm command is POSIX syntax and safe to retry', () async {
    final command = SshService.interruptedInstallDisarmCommand;
    final directory = await Directory.systemTemp.createTemp('resume-cleanup-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/disarm.sh');
    await script.writeAsString(command);

    final syntax = await Process.run('sh', ['-n', script.path]);
    expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
    // Queued phases are what an abandoned run actually leaves behind now:
    // the coordinator would run them on the next boot, against a staging
    // directory this installer is about to reuse.
    expect(command, contains(r'rm -f "$scripts"/[0-9][0-9]-*.sh'));
    expect(command, contains('installer phases are still armed'));
    // A board an older installer touched carries its post-reboot half at
    // /data/onboot.sh instead, so that one is still recognised and removed.
    expect(command, contains(r'grep -Fq "$marker" "$onboot"'));
    expect(command, contains('a legacy installer onboot script is still armed'));
    // The coordinator is retired here rather than left for a boot to notice,
    // and a user's own onboot.sh goes back where it was.
    expect(command, contains(r'grep -Fq "$shim" "$onboot"'));
    expect(command, contains(r'mv -f "$backup" "$onboot"'));
    expect(command, isNot(contains('; true')));
  });

  test('service recovery verifies masks and required active units', () async {
    final command = SshService.interruptedInstallServiceRecoveryCommand;
    final directory = await Directory.systemTemp.createTemp('resume-services-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/services.sh');
    await script.writeAsString(command);

    final syntax = await Process.run('sh', ['-n', script.path]);
    expect(syntax.exitCode, 0, reason: syntax.stderr.toString());
    expect(command, contains(r'systemctl is-enabled "$unit"'));
    expect(command, contains(r'if [ "$enabled_state" = masked ]'));
    expect(command, contains(r'systemctl is-active --quiet "$unit"'));
  });
}
