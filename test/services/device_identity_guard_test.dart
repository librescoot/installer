import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/services/device_identity_guard.dart';

void main() {
  const original = '0123456789abcdef';
  const another = 'fedcba9876543210';

  test('same chip UID survives reconnect and capitalization differences', () {
    final guard = DeviceIdentityGuard();
    expect(guard.verify('mdb', original), original);
    expect(guard.verify('mdb', original.toUpperCase()), original);
  });

  test('a different board cannot replace the bound identity', () {
    final guard = DeviceIdentityGuard()..verify('mdb', original);
    expect(
      () => guard.verify('mdb', another),
      throwsA(isA<DeviceIdentityException>()),
    );
    expect(guard.verify('mdb', original), original);
  });

  test(
    'missing or malformed identity cannot establish or resume a session',
    () {
      final guard = DeviceIdentityGuard();
      for (final serial in [null, '', 'Unknown', '01234567', '${original}0']) {
        expect(
          () => guard.verify('mdb', serial),
          throwsA(isA<DeviceIdentityException>()),
        );
      }
      guard.verify('mdb', original);
      expect(
        () => guard.verify('mdb', null),
        throwsA(isA<DeviceIdentityException>()),
      );
      expect(guard.verify('mdb', original), original);
    },
  );

  test('MDB and dashboard addresses bind independently', () {
    final guard = DeviceIdentityGuard();
    guard.verify('mdb', original);
    guard.verify('dbc', another);
    expect(guard.verify('mdb', original), original);
    expect(guard.verify('dbc', another), another);
  });

  test(
    'initial and silent authentication verify identity before publishing client',
    () {
      final source = File('lib/services/ssh_service.dart').readAsStringSync();
      final connect = source.substring(
        source.indexOf('Future<DeviceInfo> _connect('),
        source.indexOf('Future<void> _doReconnect()'),
      );
      expect(
        connect.indexOf('_verifyClientIdentity(client, host'),
        lessThan(connect.indexOf('_client = client')),
      );
      expect(
        connect.indexOf('_verifyClientIdentity(client, host'),
        lessThan(connect.indexOf('systemctl stop librescoot-pm')),
      );
      final reconnect = source.substring(
        source.indexOf('Future<void> _doReconnect()'),
        source.indexOf('Future<void> uploadFile('),
      );
      expect(
        reconnect.indexOf('_verifyClientIdentity(client, _lastHost'),
        lessThan(reconnect.indexOf('_client = client')),
      );
      expect(
        reconnect,
        contains('if (e is DeviceIdentityException) disconnect()'),
      );
      final disconnect = source.substring(
        source.indexOf('void disconnect()'),
        source.indexOf('bool get isConnected'),
      );
      expect(disconnect, isNot(contains('_deviceIdentity =')));
    },
  );
}
