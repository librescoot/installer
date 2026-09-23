import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/l10n/app_localizations_en.dart';

void main() {
  test('hands-off notice is prominent on the autonomous screen', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildDbcFlash(');
    final end = source.indexOf('Future<void> _watchDbcFlash()', start);
    final screen = source.substring(start, end);
    expect(screen, contains('l10n.dbcFlashHandsOffHeading'));
    expect(screen, contains('l10n.dbcFlashHandsOffBody'));
    expect(
      screen.indexOf('l10n.dbcFlashHandsOffHeading'),
      greaterThan(screen.indexOf('if (!_dbcUsbDisconnected)')),
    );
    expect(
      screen.indexOf('l10n.dbcFlashHandsOffHeading'),
      lessThan(screen.indexOf('EstimatedHandoffProgress(')),
    );
  });

  test('both languages name the failure and completion signals', () {
    for (final text in [
      AppLocalizationsDe().dbcFlashHandsOffBody,
      AppLocalizationsEn().dbcFlashHandsOffBody,
    ]) {
      expect(text, anyOf(contains('rot blinkt'), contains('blinks red')));
      expect(text, anyOf(contains('entsperrt'), contains('unlocked')));
    }
  });
}
