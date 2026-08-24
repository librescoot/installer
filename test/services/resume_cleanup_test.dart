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
    expect(command, contains(r'cp "$backup" "$onboot"'));
    expect(command, isNot(contains(r'mv "$backup" "$onboot"')));
    expect(command, contains(r'grep -Fq "$marker" "$onboot"'));
    expect(command, contains('installer onboot script is still armed'));
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
