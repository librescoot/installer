import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('MDB UMS starts on phase entry rather than during build', () {
    final setPhaseStart = source.indexOf('void _setPhase(');
    final setPhaseEnd = source.indexOf(
      'void _queueInstallPhaseRecord',
      setPhaseStart,
    );
    final setPhase = source.substring(setPhaseStart, setPhaseEnd);
    final buildStart = source.indexOf('Widget _buildMdbToUms(');
    final buildEnd = source.indexOf(
      'Future<void> _deactivateMainBattery',
      buildStart,
    );
    final build = source.substring(buildStart, buildEnd);

    expect(setPhase, contains('_mdbToUmsAttempt.reset();'));
    expect(setPhase, contains('Future.microtask(_startMdbToUms);'));
    expect(build, isNot(contains('Future.microtask')));
    expect(build, contains('_mdbToUmsAttempt.isFailed'));
    expect(build, contains('onPressed: _startMdbToUms'));
  });

  test('failure is published only after AutoPlay restoration', () {
    final start = source.indexOf('Future<void> _configureMdbUms(');
    final end = source.indexOf('Widget _buildMdbFlash', start);
    final block = source.substring(start, end);

    final restore = block.indexOf('await DriverService.restoreAutoPlay();');
    final failure = block.indexOf('_mdbToUmsAttempt.fail(');
    expect(restore, greaterThan(-1));
    expect(failure, greaterThan(restore));
    expect(
      block,
      contains("failureStatus =\n              'fw_setenv failed:"),
    );
    expect(block, contains('failureStatus = l10n.umsNotDetectedTimeout;'));
  });
}
