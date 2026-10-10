import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

class _Ssh extends SshService {
  final commands = <String>[];
  String execution = 'idle';

  @override
  Future<void> ensureConnected(String operation) async {}

  @override
  Future<String> runCommand(
    String command, {
    Duration timeout = const Duration(seconds: 60),
    bool replayOnDisconnect = false,
  }) async {
    commands.add(command);
    return command == SshService.installerExecutionProbeCommand
        ? execution
        : '';
  }
}

void main() {
  test('process probe does not match its own command line', () async {
    final result = await Process.run('sh', [
      '-c',
      SshService.installerExecutionProbeCommand,
    ]);
    expect(result.exitCode, 0);
    expect(result.stdout.toString().trim(), 'idle');
  });

  for (final relative in [
    'onboot.sh',
    'installer/scripts/10-mdb-artifact.sh',
    'installer/scripts/trampoline.sh',
  ]) {
    test('live $relative is protected even without a status file', () async {
      final root = await Directory.systemTemp.createTemp('execution-probe-');
      addTearDown(() => root.delete(recursive: true));
      final script = File('${root.path}/data/$relative');
      await script.parent.create(recursive: true);
      await script.writeAsString('while :; do /bin/sleep 0.05; done\n');
      final worker = await Process.start('sh', [script.path]);
      addTearDown(() async {
        worker.kill(ProcessSignal.sigkill);
        await worker.exitCode;
      });
      final result = await Process.run('sh', [
        '-c',
        SshService.installerExecutionProbeCommand.replaceAll(
          '/data/',
          '${root.path}/data/',
        ),
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout.toString().trim(), 'active');
    });
  }

  test(
    'cleanup does not match paths embedded in its flattened command line',
    () async {
      final root = await Directory.systemTemp.createTemp('cleanup-probe-');
      addTearDown(() => root.delete(recursive: true));
      final command = SshService.interruptedInstallDisarmCommand.replaceAll(
        '/data/',
        '${root.path}/data/',
      );
      final result = await Process.run('sh', [
        '-c',
        r'''
pgrep() {
  line=$(tr '\000\012' '  ' < /proc/$$/cmdline)
  printf '%s\n' "$line" | grep -Eq -- "$2"
}
systemctl() { :; }
pkill() { :; }
''' +
            command,
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    },
    skip: !Platform.isLinux,
  );

  test('cleanup refuses to stop or remove an active installer', () async {
    final ssh = _Ssh()..execution = 'active';
    await expectLater(ssh.disarmTrampolineOnboot(), throwsStateError);
    expect(ssh.commands, [SshService.installerExecutionProbeCommand]);
  });

  test('unknown ownership cannot authorize cleanup', () async {
    final ssh = _Ssh()..execution = 'unexpected output';
    await expectLater(ssh.disarmTrampolineOnboot(), throwsStateError);
    expect(ssh.commands, [SshService.installerExecutionProbeCommand]);
  });

  test('inactive queued work can be explicitly disarmed', () async {
    final ssh = _Ssh();
    await ssh.disarmTrampolineOnboot();
    expect(ssh.commands, [
      SshService.installerExecutionProbeCommand,
      SshService.interruptedInstallDisarmCommand,
    ]);
  });

  test('process inspection errors never report an idle installer', () async {
    final result = await Process.run('sh', [
      '-c',
      '''
pgrep() { return 2; }
${SshService.installerExecutionProbeCommand}
''',
    ]);
    expect(result.exitCode, 2);
    expect(result.stdout, isEmpty);
  });

  test('remote cleanup also refuses a newly executing owner', () async {
    final result = await Process.run('sh', [
      '-c',
      '''
pgrep() { return 0; }
systemctl() { echo 'unexpected service change'; }
pkill() { echo 'unexpected process kill'; }
${SshService.interruptedInstallDisarmCommand}
''',
    ]);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('cleanup is not permitted'));
    expect(result.stdout, isEmpty);
  });
}
