import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/ssh_service.dart';
import 'package:librescoot_installer/models/board_state.dart';

class _Ssh extends SshService {
  final operations = <String>[];
  bool active = false;
  bool locked = true;
  String? imageId;
  ServiceStack? stack = ServiceStack.librescoot;

  @override
  Future<Map<String, String>> readOsRelease() async => {
    if (imageId != null) 'IMAGE_ID': imageId!,
  };

  @override
  Future<ServiceStack?> detectServiceStack({int attempts = 12}) async => stack;

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

  test(
    'positively identified service-free bootstrap does not request a vehicle lock',
    () async {
      final ssh = _Ssh()
        ..imageId = 'librescoot-mdb-bootstrap'
        ..stack = ServiceStack.none
        ..locked = false;
      await ssh.prepareDashboardHandoff();
      expect(ssh.operations, ['connect']);
    },
  );

  for (final (imageId, stack) in [
    (null, ServiceStack.none),
    ('librescoot-mdb', ServiceStack.none),
    ('librescoot-mdb-bootstrap', ServiceStack.librescoot),
    ('librescoot-mdb-bootstrap', null),
  ]) {
    test(
      'absent or inconsistent bootstrap evidence cannot bypass locking: $imageId / $stack',
      () async {
        final ssh = _Ssh()
          ..imageId = imageId
          ..stack = stack
          ..locked = false;
        await expectLater(ssh.prepareDashboardHandoff(), throwsStateError);
        expect(ssh.operations, [
          'connect',
          'scooter:state:lock',
          'wait:stand-by',
        ]);
      },
    );
  }

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
