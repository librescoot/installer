import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('MDB boot starts on phase entry rather than during build', () {
    final setPhaseStart = source.indexOf('void _setPhase(');
    final setPhaseEnd = source.indexOf(
      'void _queueInstallPhaseRecord',
      setPhaseStart,
    );
    final setPhase = source.substring(setPhaseStart, setPhaseEnd);
    final buildStart = source.indexOf('Widget _buildMdbBoot(');
    final buildEnd = source.indexOf('void _startMdbBoot(', buildStart);
    final build = source.substring(buildStart, buildEnd);

    expect(setPhase, contains('_mdbBootAttempt.reset();'));
    expect(setPhase, contains('Future.microtask(_startMdbBoot);'));
    expect(build, isNot(contains('Future.microtask')));
    expect(build, contains('_mdbBootAttempt.isFailed'));
    expect(build, contains('onPressed: _startMdbBoot'));
  });

  test('privilege, data, and reconnect failures block for retry', () {
    final start = source.indexOf('Future<void> _waitForMdbBoot(');
    final end = source.indexOf('DeviceFinish _buildDeviceFinish', start);
    final block = source.substring(start, end);

    expect(source, isNot(contains('_mdbBootStarted')));
    expect(RegExp(r'_failMdbBoot\(generation,').allMatches(block).length, 3);
    expect(block, contains('on DataPartitionWaitException catch (e)'));
    expect(block, contains('l10n.sshReconnectionFailed(e.toString())'));
  });

  test('success and reflash invalidate the running generation', () {
    final start = source.indexOf('Future<void> _waitForMdbBoot(');
    final end = source.indexOf('DeviceFinish _buildDeviceFinish', start);
    final block = source.substring(start, end);

    expect(
      RegExp(
        r'_mdbBootAttempt\.complete\(generation\)',
      ).allMatches(block).length,
      3,
    );
    expect(
      RegExp(r'_ownsMdbBootAttempt\(generation\)').allMatches(block).length,
      greaterThanOrEqualTo(7),
    );
  });
}
