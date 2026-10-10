import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

void main() {
  Future<void> checkSyntax(String command) async {
    final directory = await Directory.systemTemp.createTemp('resume-syntax-');
    addTearDown(() => directory.delete(recursive: true));
    final script = File('${directory.path}/command.sh');
    await script.writeAsString(command);
    final result = await Process.run('sh', ['-n', script.path]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  }

  test('disarm command is valid POSIX syntax', () async {
    await checkSyntax(SshService.interruptedInstallDisarmCommand);
  });

  test('keycard prestart command is valid POSIX syntax', () async {
    await checkSyntax(SshService.keycardPrestartCommand);
  });

  test('service recovery command is valid POSIX syntax', () async {
    await checkSyntax(SshService.interruptedInstallServiceRecoveryCommand);
  });
}
