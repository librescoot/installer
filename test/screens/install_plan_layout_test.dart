import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/l10n/app_localizations_en.dart';

void main() {
  test('plan heading is concise and the release is named on both options', () {
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();
    expect(de.installPlanHeading, 'Installation planen');
    expect(
      de.installPlanIntro,
      'Wähle die gewünschte Aktion für Hauptboard und Display.',
    );
    expect(
      de.actionUpgradeToVersion('v1.3.1'),
      'Auf Librescoot v1.3.1 aktualisieren',
    );
    expect(
      de.actionCleanInstallVersion('v1.3.1'),
      'Librescoot v1.3.1 neu installieren',
    );
    expect(en.actionUpgradeToVersion('v1.3.1'), contains('Librescoot v1.3.1'));
    expect(
      en.actionCleanInstallVersion('v1.3.1'),
      contains('Librescoot v1.3.1'),
    );
    expect(de.planInstallTiles, 'Offline-Karten und Navigation installieren');
    expect(en.planInstallTiles, 'Install offline maps and navigation');
  });

  test('plan omits Back and keeps the region-download action', () {
    final source = File('lib/screens/installer_screen.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildInstallPlan(');
    final end = source.indexOf('void _continueFromInstallPlan()', start);
    final planScreen = source.substring(start, end);
    expect(planScreen, contains('subtitle: l10n.installPlanIntro'));
    expect(planScreen, isNot(contains('onBack:')));
    expect(planScreen, isNot(contains('backLabel:')));
    expect(planScreen, contains('label: l10n.planChangeOfflineMaps'));
  });
}
