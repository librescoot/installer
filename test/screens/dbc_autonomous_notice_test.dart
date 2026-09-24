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
    expect(screen, contains('DbcFlashOutcomes('));
    expect(screen, isNot(contains('_blinkerPhases(')));
    expect(screen, isNot(contains('l10n.dbcFlashSequence')));
  });

  test('both languages give a concise hands-off warning', () {
    expect(
      AppLocalizationsDe().dbcFlashHandsOffBody,
      contains('Keine Kabel oder Batterien trennen'),
    );
    expect(
      AppLocalizationsEn().dbcFlashHandsOffBody,
      contains('Do not disconnect cables or batteries'),
    );
  });
}
