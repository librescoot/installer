import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';

class _Ssh extends SshService {
  final operations = <String>[];
  bool active = false;
  bool locked = true;

  @override
  Future<void> ensureConnected(String operation) async {
    operations.add('connect');
  }

  @override
  Future<bool> installerExecutionActive() async => active;

  @override
  Future<void> redisLpush(
    String key,
    String value, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    operations.add('$key:$value');
  }

  @override
  Future<bool> waitForVehicleState(
    String targetState, {
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(seconds: 2),
  }) async {
    operations.add('wait:$targetState');
    return locked;
  }
}

void main() {
  test('handoff explicitly locks and verifies vehicle stand-by', () async {
    final ssh = _Ssh();
    await ssh.prepareDashboardHandoff();
    expect(ssh.operations, ['connect', 'scooter:state:lock', 'wait:stand-by']);
  });

  test('failed lock confirmation prevents handoff', () async {
    final ssh = _Ssh()..locked = false;
    await expectLater(ssh.prepareDashboardHandoff(), throwsStateError);
    expect(ssh.operations, ['connect', 'scooter:state:lock', 'wait:stand-by']);
  });

  test(
    'an executing coordinator is never disturbed by a new lock request',
    () async {
      final ssh = _Ssh()..active = true;
      await expectLater(ssh.prepareDashboardHandoff(), throwsStateError);
      expect(ssh.operations, ['connect']);
    },
  );

  test('the UI verifies locking before arming or launching phases', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.substring(
      source.indexOf('Future<void> _startTrampoline()'),
      source.indexOf('Future<String?> _saveTrampolineFailureDiagnostics'),
    );
    expect(
      start.indexOf('prepareDashboardHandoff()'),
      lessThan(start.indexOf('_armInstallPhases(')),
    );
    expect(
      start.indexOf('prepareDashboardHandoff()'),
      lessThan(start.indexOf('trampoline.start(')),
    );
  });
}
