import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed reconnect leaves restored settings and services alone', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _verifyDbcFlash(int generation)');
    final end = source.indexOf('\n  /// Put the trampoline', start);
    final reconnect = source.substring(start, end);

    final completion = reconnect.indexOf(
      'final completed = await _deviceReportedFinished()',
    );
    expect(completion, greaterThan(-1));
    expect(
      reconnect.substring(0, completion),
      contains('l10n.checkingCompletionRecord'),
    );
    expect(
      reconnect,
      isNot(contains("_disableInstallerHazards(label: 'reconnect')")),
    );
    expect(reconnect, isNot(contains("Substep(id: 'hazards'")));

    final guard = reconnect.substring(completion);
    expect(guard, contains('if (completed == true)'));
    expect(guard, contains('_finishCompletionConfirmed = true'));
    expect(guard, contains('_setPhase(InstallerPhase.finish)'));
    expect(guard, contains('return;'));
  });

  test('All done proactively checks an already reconnected MDB', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _finishAfterDbcSuccess()');
    final end = source.indexOf('\n  Future<void> _verifyDbcFlash(int generation)', start);
    final finish = source.substring(start, end);

    final detect = finish.indexOf('_usbDetector.detectDevice()');
    final refresh = finish.indexOf('_refreshFinishCompletion()');
    final advance = finish.indexOf('_setPhase(InstallerPhase.finish)');
    expect(detect, greaterThan(-1));
    expect(refresh, greaterThan(detect));
    expect(advance, greaterThan(refresh));
    expect(
      source,
      contains('onPressed: _isProcessing ? null : _finishAfterDbcSuccess'),
    );
  });

  test('a USB event on Finish polls through late ssh and finalization', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    expect(
      source,
      contains('device != null && _currentPhase == InstallerPhase.finish'),
    );
    expect(source, contains('unawaited(_refreshFinishCompletion())'));

    final start = source.indexOf('Future<void> _refreshFinishCompletion()');
    final end = source.indexOf('\n  /// Progress for the transfer', start);
    final refresh = source.substring(start, end);
    expect(refresh, contains('for (var attempt = 1; attempt <= attempts;'));
    expect(refresh, contains('connectToMdbForStatus()'));
    expect(refresh, contains('_deviceReportedFinished()'));
    expect(refresh, contains('Duration(seconds: 3)'));
  });

  test('status reconnect cannot stop the restored power manager', () {
    final source = File('lib/services/ssh_service.dart').readAsStringSync();
    final statusStart = source.indexOf('connectToMdbForStatus()');
    final statusEnd = source.indexOf('\n\n', statusStart);
    final statusConnect = source.substring(statusStart, statusEnd);
    expect(statusConnect, contains('stopPowerManager: false'));

    final connectStart = source.indexOf('Future<DeviceInfo> _connect(');
    final connectEnd = source.indexOf(
      '\n  Future<({String? version, String? osId})>',
      connectStart,
    );
    final connect = source.substring(connectStart, connectEnd);
    expect(connect, contains('if (stopPowerManager)'));
    expect(
      connect.indexOf('if (stopPowerManager)'),
      lessThan(connect.indexOf('systemctl stop librescoot-pm')),
    );
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
