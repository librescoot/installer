import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('a launch failure offers restoration instead of a generic skip', () {
    expect(source, contains('_trampolineStartFailed = true'));
    expect(source, contains('l10n.restoreScooterWithoutTransfer'));
    expect(source, contains('onPressed: busy ? null : _skipDashboardTransfer'));
  });

  test('closing is blocked until failed-transfer restoration is handed off', () {
    expect(
      source,
      contains('_dashboardTransferSkipped && !_deviceFinishArmed'),
    );
    expect(source, contains('l10n.restoreScooterBeforeClosing'));
    expect(source, contains('_deviceFinishArmed = true;'));
  });

  test('a skipped transfer is not recorded as installed', () {
    expect(source, contains("? 'skipped'"));
    expect(source, contains("? ''"));
    expect(source, contains('l10n.finishTransferSkippedConfirmed'));
  });
}
