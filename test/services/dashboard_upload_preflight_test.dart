import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/dashboard_upload_preflight.dart';

void main() {
  late List<String> calls;
  late bool owns;
  late List<bool> active;
  late String? failure;
  late String? cancelAt;

  Future<bool> prepare() => prepareDashboardUpload(
    owns: () => owns,
    connectForStatus: () async {
      calls.add('status-connect');
      if (failure == 'connect') throw StateError('unreachable');
      if (cancelAt == 'connect') owns = false;
    },
    verifyUsbRoute: () async {
      calls.add('usb-route');
      if (failure == 'route') throw StateError('not USB');
      if (cancelAt == 'route') owns = false;
    },
    installerActive: () async {
      calls.add('owner');
      if (failure == 'owner') throw StateError('unknown owner');
      return active.removeAt(0);
    },
    observeActive: () async => calls.add('observe'),
    connectForWork: () async {
      calls.add('work-connect');
      if (cancelAt == 'work') owns = false;
    },
  );

  setUp(() {
    calls = [];
    owns = true;
    active = [false, false];
    failure = null;
    cancelAt = null;
  });

  test(
    'read-only reconnection and route/owner checks precede staging',
    () async {
      expect(await prepare(), isTrue);
      expect(calls, [
        'status-connect',
        'usb-route',
        'owner',
        'work-connect',
        'usb-route',
        'owner',
      ]);
    },
  );

  test('active owner is observed without a work connection', () async {
    active = [true];
    expect(await prepare(), isFalse);
    expect(calls, ['status-connect', 'usb-route', 'owner', 'observe']);
  });

  test('ownership is checked again after work reconnection', () async {
    active = [false, true];
    expect(await prepare(), isFalse);
    expect(calls.last, 'observe');
  });

  for (final stage in ['connect', 'route', 'owner']) {
    test('$stage failure blocks staging', () async {
      failure = stage;
      await expectLater(prepare(), throwsStateError);
      expect(calls, isNot(contains('work-connect')));
      expect(calls, isNot(contains('observe')));
    });
  }

  for (final stage in ['connect', 'route', 'work']) {
    test('superseded upload stops after $stage', () async {
      cancelAt = stage;
      expect(await prepare(), isFalse);
      expect(calls, isNot(contains('observe')));
    });
  }

  test('cancelled before starting does not connect', () async {
    owns = false;
    expect(await prepare(), isFalse);
    expect(calls, isEmpty);
  });
}
