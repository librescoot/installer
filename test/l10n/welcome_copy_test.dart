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
      expect(
        l10n.prerequisiteUsbCable,
        'Ein USB-Mini-B-Kabel, um deinen Computer mit dem MDB zu verbinden',
      );
      expect(l10n.shopUsbCable, 'Kabel im Shop');
      expect(l10n.firmwareChannel, 'Firmware auswählen');
      expect(l10n.region, contains('Navigation'));
      expect(l10n.skipOfflineMaps, contains('Navigation'));
    },
  );

  test(
    'Welcome lists administrator access and offline navigation in English',
    () {
      final l10n = AppLocalizationsEn();
      expect(l10n.prerequisiteAdminAccess, 'Administrator privileges');
      expect(l10n.prerequisiteUsbCable, contains('USB Mini-B cable'));
      expect(l10n.shopUsbCable, 'Cable in shop');
      expect(l10n.firmwareChannel, 'Choose firmware');
      expect(l10n.region, contains('navigation'));
      expect(l10n.skipOfflineMaps, contains('navigation data'));
    },
  );

  test('Welcome presents administrator access as a prerequisite', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    expect(source, contains('l10n.prerequisiteAdminAccess,'));
    expect(
      source,
      contains("'https://shop.librescoot.org/product/mini-usb-kabel-mdb/'"),
    );
    expect(source, contains('l10n.shopUsbCable'));
    expect(source, contains('mode: LaunchMode.externalApplication'));
    expect(
      source,
      contains(
        'final List<bool> _prerequisiteChecks = [false, false, false, false, false]',
      ),
    );
    expect(source, isNot(contains('l10n.regionHint')));
    expect(source, isNot(contains('l10n.firmwareChannelHint')));
    expect(
      source,
      contains('Expanded(\n            child: Text(\n              text,'),
    );
  });
}
