import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();

  test('pairing cleanup resets an absent bootstrap state to stand-by', () {
    final start = source.indexOf('Future<void> _restorePairingVehicleState()');
    final end = source.indexOf('Future<void> _stopBluetoothPairing(', start);
    final cleanup = source.substring(start, end);

    expect(
      cleanup,
      contains("final before = _stateBeforePairing ?? 'stand-by'"),
    );
    expect(cleanup, isNot(contains('before == null')));
    expect(cleanup, contains('await _sshService.forceVehicleState(before)'));
    expect(cleanup, contains('if (before == \'parked\')'));
    final write = cleanup.indexOf(
      'await _sshService.forceVehicleState(before)',
    );
    expect(
      cleanup.indexOf('_pairingVehicleStateChanged = false;', write),
      greaterThan(write),
    );
    expect(cleanup, contains('rethrow;'));
  });

  test('a stale pairing start also resets an absent state to stand-by', () {
    final start = source.indexOf('Future<void> stopStaleStart()');
    final end = source.indexOf('\n    try {', start);
    final cleanup = source.substring(start, end);

    expect(cleanup, contains('claimedVehicleStateChange'));
    expect(cleanup, isNot(contains('claimedVehicleState != null')));
    expect(cleanup, contains("claimedVehicleState ?? 'stand-by'"));
    expect(cleanup, contains('await _sshService.forceVehicleState('));
  });
}
