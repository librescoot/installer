import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/l10n/app_localizations_en.dart';

void main() {
  test(
    'Welcome lists administrator access and offline navigation in German',
    () {
      final l10n = AppLocalizationsDe();
      expect(l10n.requirementsIntro, contains('Laptop mit Administratorrechten'));
      expect(l10n.prerequisiteUsbCable, 'USB-Mini-B-Datenkabel');
      expect(l10n.requirementsVideoLink, 'Videoanleitung ansehen ↗');
      expect(l10n.elevationNoticeWelcome, contains('fragt nach Administratorrechten'));
      expect(l10n.elevationNoticeWelcome, contains('USB-Verbindung einzurichten'));
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
        contains('Laptop with administrator access'),
      );
      expect(l10n.prerequisiteUsbCable, contains('USB Mini-B data cable'));
      expect(l10n.requirementsVideoLink, 'Watch the installation video ↗');
      expect(l10n.elevationNoticeWelcome, contains('requests administrator access'));
      expect(l10n.elevationNoticeWelcome, contains('write software to the scooter'));
      expect(l10n.firmwareChannel, 'Choose firmware');
      expect(l10n.region, contains('navigation'));
      expect(l10n.skipOfflineMaps, contains('navigation data'));
    },
  );

  test('Welcome uses the linked requirements list', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    expect(
      source,
      contains('WelcomeRequirements(onOpenUrl: _openExternalUrl)'),
    );
    expect(source, contains('footerLeading: needsAdmin'));
    expect(source, contains('needsAdmin ? Icons.shield_outlined'));
    expect(source, isNot(contains('_prerequisiteChecks')));
  });
}
