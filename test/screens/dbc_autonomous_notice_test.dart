import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hands-off notice is prominent on the autonomous screen', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildDbcFlash(');
    final end = source.indexOf('Future<void> _watchDbcFlash()', start);
    final screen = source.substring(start, end);
    final status = File(
      'lib/widgets/dashboard_handoff_status.dart',
    ).readAsStringSync();
    expect(screen, contains('_dbcShowingStatus && _dbcDisconnectedAt != null'));
    expect(screen, contains('l10n.handoffShowStatus'));
    expect(status, contains('l10n.dbcFlashHandsOffHeading'));
    expect(screen, isNot(contains('l10n.dbcFlashHandsOffBody')));
    expect(status, contains('EstimatedHandoffProgress('));
    expect(status, contains('startedAt: disconnectedAt'));
    expect(screen, contains('l10n.handoffLedSignals'));
    expect(screen, contains('l10n.handoffDisconnected'));
    expect(status, contains('l10n.handoffHandsOffBody'));
    expect(status, contains('DbcFlashOutcomes('));
    expect(
      status.indexOf('l10n.dbcFlashHandsOffHeading'),
      lessThan(status.indexOf('EstimatedHandoffProgress(')),
    );
    expect(
      status.indexOf('l10n.dbcFlashChooseOutcomeHint'),
      lessThan(status.indexOf('DbcFlashOutcomes(')),
    );
    expect(screen, isNot(contains('_blinkerPhases(')));
    expect(screen, isNot(contains('l10n.dbcFlashSequence')));
  });
}
