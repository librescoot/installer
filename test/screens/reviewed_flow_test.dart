import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/installer_screen.dart').readAsStringSync();
  String section(String start, String end) {
    final offset = source.indexOf(start);
    expect(offset, greaterThanOrEqualTo(0));
    return source.substring(offset, source.indexOf(end, offset));
  }

  test(
    'preparation separates crossbars from cabling and unlocks after cabling',
    () {
      final prep = section(
        'Widget _buildPhysicalPrep(',
        'Future<bool> _ensureDriverBinding',
      );
      expect(prep, contains('l10n.continueToUsb'));
      expect(prep, contains('l10n.removeBraces'));
      expect(
        prep.indexOf('title: l10n.keepScooterAwake'),
        greaterThan(prep.indexOf('title: l10n.connectLaptopUsb')),
      );
    },
  );

  test(
    'automatic handoff cannot show unplug instructions before device acknowledgement',
    () {
      final start = section(
        'Future<void> _startTrampoline()',
        'Future<String?> _saveTrampolineFailureDiagnostics',
      );
      final real = start.substring(start.indexOf('    try {'));
      expect(
        real.indexOf('await TrampolineService(_sshService).start'),
        lessThan(real.indexOf('_setPhase(InstallerPhase.dbcFlash)')),
      );
      final prep = section(
        'Widget _buildDbcPrep(',
        'SubstepLabels _substepLabels',
      );
      expect(prep, contains('_dbcUploadReady &&'));
      expect(prep, contains('!_trampolineStartFailed'));
      expect(prep, contains('Future.microtask(_startTrampoline)'));
    },
  );

  test(
    'observing USB absence does not report dashboard installation or completion',
    () {
      final watch = section(
        'Future<void> _watchDbcFlash()',
        'Widget _buildReconnect(',
      );
      expect(watch, contains('_setStatus(l10n.handoffDisconnected)'));
      expect(watch, isNot(contains('mdbDisconnectedFlashingDbc')));
      expect(watch, isNot(contains('_unlockObserved = true')));
      expect(watch, contains('_dbcDisconnectedAt = DateTime.now()'));
      expect(
        watch.indexOf('_dbcDisconnectedAt = DateTime.now()'),
        greaterThan(watch.indexOf('_dbcUsbDisconnected = true')),
      );
      expect(watch, contains('_currentPhase != InstallerPhase.dbcFlash'));
    },
  );

  test('incomplete result is separate from pending and successful finish', () {
    final finish = section(
      'Widget _buildFinish(',
      'Widget _buildMdbOnlyFinishPending(',
    );
    expect(
      finish.indexOf('_buildIncompleteResult('),
      lessThan(finish.indexOf('l10n.welcomeToLibrescoot')),
    );
    final result = section(
      'Widget _buildIncompleteResult(',
      'Widget _buildFinish(',
    );
    expect(result, contains('_returnToDbcPrep'));
    expect(result, contains('confirmed: false'));
    expect(result, isNot(contains('_buildGettingStarted')));
    expect(result, isNot(contains('_finalSteps')));
  });

  test('configuration verification gates reassembly and welcome', () {
    final finish = section(
      'Widget _buildFinish(',
      'Widget _buildMdbOnlyFinishPending(',
    );
    expect(
      finish.indexOf('!configurationConfirmed'),
      lessThan(finish.indexOf('_buildReassembly(')),
    );
    expect(
      finish,
      contains(
        '_configurationRestoreVerified && _configurationPostFinalizeVerified',
      ),
    );
  });

  test('dry-run success never probes or configures physical USB', () {
    final success = section(
      'Future<void> _finishAfterDbcSuccess()',
      'Future<void> _startDbcVerification()',
    );
    final dry = success.indexOf('if (!_isDryRun)');
    final hardware = success.indexOf('_usbDetector.detectDevice()');
    expect(dry, greaterThan(0));
    expect(dry, lessThan(hardware));
    expect(
      success.indexOf('await _refreshFinishCompletion();'),
      greaterThan(hardware),
    );
    expect(source, contains('if (!_isDryRun) _usbDetector.startMonitoring()'));
  });
}
