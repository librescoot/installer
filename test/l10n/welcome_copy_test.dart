import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/l10n/app_localizations_en.dart';

void main() {
  test(
    'Welcome lists administrator access and offline navigation in German',
    () {
      final l10n = AppLocalizationsDe();
      expect(l10n.requirementsIntro, contains('Admin-Rechte auf dem Computer'));
      expect(l10n.prerequisiteUsbCable, 'ein USB-Mini-B-Kabel');
      expect(l10n.requirementsVideoLink, 'Videoanleitung ansehen ↗');
      expect(l10n.firmwareChannel, 'Firmware auswählen');
      expect(l10n.region, contains('Navigation'));
      expect(l10n.skipOfflineMaps, contains('Navigation'));
    },
  );

  test(
    'Welcome lists administrator access and offline navigation in English',
    () {
      final l10n = AppLocalizationsEn();
      expect(
        l10n.requirementsIntro,
        contains('administrator rights on your computer'),
      );
      expect(l10n.prerequisiteUsbCable, contains('USB Mini-B cable'));
      expect(l10n.requirementsVideoLink, 'Watch the installation video ↗');
      expect(l10n.firmwareChannel, 'Choose firmware');
      expect(l10n.region, contains('navigation'));
      expect(l10n.skipOfflineMaps, contains('navigation data'));
    },
  );

  test('Welcome uses the linked requirements paragraph', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    expect(
      source,
      contains('WelcomeRequirements(onOpenUrl: _openExternalUrl)'),
    );
    expect(source, isNot(contains('_prerequisiteChecks')));
  });
}
