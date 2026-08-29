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

    final guard = reconnect.substring(completion, hazards);
    expect(guard, contains('if (completed == true)'));
    expect(guard, contains('_finishCompletionConfirmed = true'));
    expect(guard, contains('_setPhase(InstallerPhase.finish)'));
    expect(guard, contains('return;'));
  });
}
