import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed reconnect leaves restored settings and services alone', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _verifyDbcFlash()');
    final end = source.indexOf('\n  /// Put the trampoline', start);
    final reconnect = source.substring(start, end);

    final completion = reconnect.indexOf(
      'final completed = await _deviceReportedFinished()',
    );
    final hazards = reconnect.indexOf(
      "_disableInstallerHazards(label: 'reconnect')",
    );
    expect(completion, greaterThan(-1));
    expect(hazards, greaterThan(completion));
    expect(
      reconnect.substring(0, completion),
      contains('l10n.checkingCompletionRecord'),
    );

    final guard = reconnect.substring(completion, hazards);
    expect(guard, contains('if (completed == true)'));
    expect(guard, contains('_finishCompletionConfirmed = true'));
    expect(guard, contains('_setPhase(InstallerPhase.finish)'));
    expect(guard, contains('return;'));
  });

  test('All done proactively checks an already reconnected MDB', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _finishAfterDbcSuccess()');
    final end = source.indexOf('\n  Future<void> _verifyDbcFlash()', start);
    final finish = source.substring(start, end);

    final detect = finish.indexOf('_usbDetector.detectDevice()');
    final refresh = finish.indexOf('_refreshFinishCompletion()');
    final advance = finish.indexOf('_setPhase(InstallerPhase.finish)');
    expect(detect, greaterThan(-1));
    expect(refresh, greaterThan(detect));
    expect(advance, greaterThan(refresh));
    expect(source, contains('onPressed: _isProcessing ? null : _finishAfterDbcSuccess'));
  });

  test('a USB event on Finish remains the late-reconnect fallback', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    expect(
      source,
      contains('device != null && _currentPhase == InstallerPhase.finish'),
    );
    expect(source, contains('unawaited(_refreshFinishCompletion())'));
  });

  test('fallback wording names the active probes, not the trampoline', () {
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_de.arb']) {
      final text = File(arb).readAsStringSync();
      expect(text, contains('substepCheckCompletionRecord'));
      expect(text, isNot(contains('Read trampoline status')));
      expect(text, isNot(contains('Trampoline-Status auslesen')));
    }
  });
}
