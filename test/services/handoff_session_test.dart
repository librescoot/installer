import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';
import 'package:librescoot_installer/services/trampoline_service.dart';

class _Ssh extends SshService {
  final commands = <String>[];
  bool running = false;
  bool usbRoute = true;
  bool sameWaitingRun = true;
  String ready = 'run-1';

  @override
  Future<void> writeInstallRunState({
    required String runId,
    required String content,
  }) async {}

  @override
  Future<String> runCommand(
    String command, {
    Duration timeout = const Duration(seconds: 60),
    bool replayOnDisconnect = false,
  }) async {
    commands.add(command);
    if (command.startsWith('pgrep')) return running ? '123' : '';
    if (command.contains('echo occupied')) return 'clear';
    if (command.contains('echo waiting')) {
      return sameWaitingRun ? 'waiting' : '';
    }
    if (command.contains('echo present')) return usbRoute ? 'present' : '';
    if (command.contains('nohup sh')) {
      running = true;
      return '';
    }
    if (command.endsWith('/ready 2>/dev/null; true')) return ready;
    return '';
  }
}

void main() {
  test(
    'launch requires this run readiness acknowledgement, not just a PID',
    () async {
      final ssh = _Ssh()..ready = 'another-run';
      final service = TrampolineService(ssh, handoffPollDelay: Duration.zero);
      await expectLater(
        service.start(runId: 'run-1'),
        throwsA(isA<TrampolineStartException>()),
      );
      expect(ssh.running, isTrue);
    },
  );

  test(
    'valid launch receives readiness and maintains USB presence lease',
    () async {
      final ssh = _Ssh();
      await TrampolineService(
        ssh,
        handoffPollDelay: Duration.zero,
      ).start(runId: 'run-1');
      expect(ssh.commands.where((c) => c.contains('nohup sh')), hasLength(1));
      expect(
        ssh.commands.where((c) => c.contains('echo present')).length,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test(
    'lost acknowledgement can resume the same waiting run without relaunch',
    () async {
      final ssh = _Ssh()..running = true;
      await TrampolineService(
        ssh,
        handoffPollDelay: Duration.zero,
      ).start(runId: 'run-1');
      expect(
        ssh.commands.any((c) => c.contains('nohup') || c.contains('rm -rf')),
        isFalse,
      );
    },
  );

  test('an active installation or different run is never replaced', () async {
    final ssh = _Ssh()
      ..running = true
      ..sameWaitingRun = false;
    await expectLater(
      TrampolineService(ssh).start(runId: 'run-1'),
      throwsStateError,
    );
    expect(
      ssh.commands.any((c) => c.contains('nohup') || c.contains('rm -rf')),
      isFalse,
    );
  });

  test('non-USB installer connection cannot arm a handoff', () async {
    final ssh = _Ssh()..usbRoute = false;
    await expectLater(
      TrampolineService(ssh).start(runId: 'run-1'),
      throwsStateError,
    );
    expect(ssh.commands.any((c) => c.contains('nohup')), isFalse);
  });

  test('cancellation cannot override an acquired installation claim', () async {
    final ssh = _Ssh()..running = true;
    expect(await TrampolineService(ssh).cancelWaiting(runId: 'run-1'), isFalse);
    expect(
      ssh.commands.any((c) => c.contains('kill') || c.contains('rm -rf')),
      isFalse,
    );
  });

  test(
    'reconnecting the laptop resumes only an acknowledged waiting run',
    () async {
      final ssh = _Ssh()..running = true;
      final service = TrampolineService(ssh);
      expect(await service.resumeWaiting(runId: 'run-1'), isTrue);
      ssh.sameWaitingRun = false;
      expect(await service.resumeWaiting(runId: 'run-1'), isFalse);
      expect(
        ssh.commands.any((c) => c.contains('nohup') || c.contains('rm -rf')),
        isFalse,
      );
    },
  );

  test('lease and cancellation reject shell/path injection', () async {
    final ssh = _Ssh();
    final service = TrampolineService(ssh);
    await expectLater(
      service.heartbeat(runId: '../bad;command'),
      throwsArgumentError,
    );
    await expectLater(
      service.cancelWaiting(runId: '../bad;command'),
      throwsArgumentError,
    );
    expect(ssh.commands, isEmpty);
  });
}
