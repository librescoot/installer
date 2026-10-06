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
    expect(screen, isNot(contains('l10n.dbcFlashHandsOffBody')));
    expect(
      screen.indexOf('l10n.dbcFlashHandsOffHeading'),
      greaterThan(screen.indexOf('if (_dbcUsbDisconnected)')),
    );
    expect(screen, contains('HandoffDuration('));
    expect(screen, isNot(contains('EstimatedHandoffProgress(')));
    expect(screen, contains('l10n.handoffLedSignals'));
    expect(screen, contains('l10n.handoffDisconnected'));
    expect(screen, contains('l10n.handoffHandsOffBody'));
    expect(
      screen.indexOf('l10n.dbcFlashHandsOffHeading'),
      greaterThan(screen.indexOf('HandoffDuration(')),
    );
    expect(screen, contains('DbcFlashOutcomes('));
    expect(
      screen.indexOf('l10n.dbcFlashChooseOutcomeHint'),
      greaterThan(screen.indexOf('HandoffDuration(')),
    );
    expect(
      screen.indexOf('l10n.dbcFlashChooseOutcomeHint'),
      lessThan(screen.indexOf('DbcFlashOutcomes(')),
    );
    expect(screen, isNot(contains('_blinkerPhases(')));
    expect(screen, isNot(contains('l10n.dbcFlashSequence')));
  });

  test('both languages distinguish dashboard power-on from completion', () {
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();
    expect(
      de.dbcFlashHandsOffHeading,
      contains('Dashboard an heißt noch nicht fertig'),
    );
    expect(de.handoffHandsOffBody, contains('Stromversorgung angeschlossen'));
    expect(
      en.dbcFlashHandsOffHeading,
      contains('DASHBOARD ON DOES NOT MEAN DONE'),
    );
    expect(en.dbcFlashHandsOffHeading, contains('HANDS OFF'));
    expect(
      de.dbcFlashChooseOutcomeHint,
      'Wenn eines dieser beiden Ereignisse eintritt, klicke das passende Bild.',
    );
    expect(
      en.dbcFlashChooseOutcomeHint,
      'When either of these happens, click the matching picture.',
    );
    expect(
      de.dbcFlashErrorPrompt,
      'Warnblinker geht an, die LED am Dashboard blinkt rot',
    );
    expect(en.dbcFlashErrorPrompt, 'Hazard lights turn on, DBC LED blinks red');
  });
}
