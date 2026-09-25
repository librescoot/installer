import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/l10n/app_localizations_en.dart';

void main() {
  test(
    'Welcome lists administrator access and offline navigation in German',
    () {
      final l10n = AppLocalizationsDe();
      expect(l10n.prerequisiteAdminAccess, 'Administratorrechte');
      expect(l10n.firmwareChannel, 'Firmware auswählen');
      expect(l10n.firmwareChannelHint, contains('Stabil'));
      expect(l10n.region, contains('Navigation'));
      expect(l10n.regionHint, contains('Navigationsdaten'));
      expect(l10n.regionHint, isNot(contains('installiert wird')));
      expect(l10n.skipOfflineMaps, contains('Navigation'));
    },
  );

  test(
    'Welcome lists administrator access and offline navigation in English',
    () {
      final l10n = AppLocalizationsEn();
      expect(l10n.prerequisiteAdminAccess, 'Administrator privileges');
      expect(l10n.firmwareChannel, 'Choose firmware');
      expect(l10n.firmwareChannelHint, contains('Stable'));
      expect(l10n.region, contains('navigation'));
      expect(l10n.regionHint, contains('navigation data'));
      expect(l10n.regionHint, isNot(contains('Installation is selected')));
      expect(l10n.skipOfflineMaps, contains('navigation data'));
    },
  );

  test('Welcome presents administrator access as a prerequisite', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    expect(source, contains('l10n.prerequisiteAdminAccess,'));
    expect(
      source,
      contains(
        'final List<bool> _prerequisiteChecks = [false, false, false, false, false]',
      ),
    );
    expect(source, contains('l10n.firmwareChannelHint'));
  });
}
