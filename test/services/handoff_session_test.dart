import 'dart:io';

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
    if (command.contains('echo usb-route')) {
      return usbRoute ? 'usb-route' : 'not usb0';
    }
    if (command.contains('echo present')) {
      return usbRoute ? 'present' : 'not usb0';
    }
    if (command.contains('nohup sh')) {
      running = true;
      return '';
    }
    if (command.endsWith('/ready 2>/dev/null; true')) return ready;
    return '';
  }
}

void main() {
  Future<ProcessResult> probe({
    String connection = '192.168.7.50 4321 192.168.7.1 22',
    String client = '',
    String route = '192.168.7.50 dev usb0 src 192.168.7.1',
    int routeExit = 0,
  }) => Process.run('sh', [
    '-c',
    '''
SSH_CONNECTION='$connection'
SSH_CLIENT='$client'
ip() { printf '%s\\n' '$route'; return $routeExit; }
$handoffUsbRouteCheck
if handoff_usb_route; then echo usb-route; fi
''',
  ]);

  test(
    'USB route check accepts both SSH server peer environment forms',
    () async {
      expect((await probe()).stdout.toString().trim(), 'usb-route');
      expect(
        (await probe(
          connection: '',
          client: '192.168.7.50 4321 22',
        )).stdout.toString().trim(),
        'usb-route',
      );
    },
  );

  test(
    'authoritative connection peer never falls back to a USB-looking client',
    () async {
      final result = await probe(
        connection: '10.0.0.20 4321 10.0.0.1 22',
        client: '192.168.7.50 4321 22',
        route: '10.0.0.20 dev wlan0 src 10.0.0.1',
      );
      expect(result.stdout, contains('not routed through usb0'));
      expect(result.stdout, isNot(contains('usb-route')));
    },
  );

  test(
    'missing SSH peer and failed route lookup fail closed with diagnostics',
    () async {
      expect((await probe(connection: '')).stdout, contains('did not provide'));
      final result = await probe(
        route: 'ip: unsupported route lookup',
        routeExit: 1,
      );
      expect(result.stdout, contains('USB route lookup failed'));
      expect(result.stdout, isNot(contains('usb-route')));
    },
  );

  test('similarly named interfaces are not the USB gadget interface', () async {
    for (final iface in ['usb01', 'usb0evil', 'eth0', 'wlan0']) {
      expect(
        (await probe(route: '192.168.7.50 dev $iface')).stdout,
        isNot(contains('usb-route')),
      );
    }
  });

  test('route preflight precedes phase arming and failure stays visible', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _startTrampoline()');
    final launch = source.substring(
      start,
      source.indexOf(
        'Future<String?> _saveTrampolineFailureDiagnostics',
        start,
      ),
    );
    expect(
      launch.indexOf('await trampoline.verifyUsbRoute()'),
      lessThan(launch.indexOf('await _armInstallPhases')),
    );
    expect(
      source,
      contains('error: _trampolineStartFailed ? _statusMessage : null'),
    );
    expect(launch, contains('l10n.handoffPreparationError(e.toString())'));
  });

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
