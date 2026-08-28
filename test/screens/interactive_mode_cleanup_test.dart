import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('BLE cleanup tracks each successfully entered remote mode', () {
    final start = source.indexOf('Future<void> _startBluetoothPairing()');
    final stop = source.indexOf('Future<void> _stopBluetoothPairing(', start);
    final block = source.substring(start, stop);

    expect(
      block.indexOf("forceVehicleState('parked')"),
      lessThan(block.indexOf('_pairingVehicleStateChanged = true;')),
    );
    expect(
      block.indexOf("'advertising-restart-no-whitelisting'"),
      lessThan(block.indexOf('_bleWhitelistDisabled = true;')),
    );
  });

  test('close restores either BLE mode even before pairing becomes active', () {
    final cleanup = source.indexOf('Future<void> _cleanupBeforeClose()');
    final retry = source.indexOf('Future<bool> _shouldRetry', cleanup);
    final block = source.substring(cleanup, retry);

    expect(block, contains('_bleWhitelistDisabled'));
    expect(block, contains('_pairingVehicleStateChanged'));
    expect(block, contains('_stopBluetoothPairing(advance: false)'));
  });

  test('regular and master keycard learning each have a bounded stop', () {
    final start = source.indexOf('Future<void> _stopActiveKeycardModes()');
    final end = source.indexOf('Future<void> _cleanupKeycardPhase()', start);
    final block = source.substring(start, end);

    expect(block, contains('if (_keycardLearning)'));
    expect(block, contains("'learn:stop'"));
    expect(block, contains('if (_keycardMasterLearning)'));
    expect(block, contains("'learn:master:stop'"));
    expect(block, contains('runBoundedCleanupActions'));
  });

  test('leaving keycard setup invokes remote cleanup before teardown', () {
    final phase = source.indexOf('void _setPhase(InstallerPhase phase)');
    final record = source.indexOf('void _queueInstallPhaseRecord', phase);
    final block = source.substring(phase, record);

    expect(block, contains('unawaited(_cleanupKeycardPhase())'));
  });

  test('BLE polling bounds the SSH sessions themselves', () {
    final start = source.indexOf('void _startBleAdvRearm()');
    final stop = source.indexOf(
      'Future<void> _restoreBluetoothWhitelist()',
      start,
    );
    final block = source.substring(start, stop);

    expect(block, isNot(contains('.timeout(const Duration(seconds: 2))')));
    expect(block, contains('redis-cli --raw HMGET ble status pin-code'));
    expect(
      RegExp(r'timeout: const Duration\(seconds: 2\)').allMatches(block).length,
      2,
    );
  });
}
