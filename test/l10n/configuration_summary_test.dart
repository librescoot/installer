import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/l10n/app_localizations_en.dart';
import 'package:librescoot_installer/l10n/configuration_summary.dart';

void main() {
  test('German health check names both transferable categories', () {
    expect(
      configurationDetectedSummary(AppLocalizationsDe(), [
        'Schlüsselkarten',
        'Cloud-Konfiguration',
      ]),
      'Folgende Daten können übertragen werden: Schlüsselkarten und Cloud-Konfiguration.',
    );
  });

  test('one German category uses singular agreement', () {
    expect(
      configurationDetectedSummary(AppLocalizationsDe(), ['Schlüsselkarten']),
      'Folgende Daten können übertragen werden: Schlüsselkarten.',
    );
  });

  test('English lists three categories naturally', () {
    expect(
      configurationDetectedSummary(AppLocalizationsEn(), [
        'Scooter settings',
        'Keycards',
        'Cloud configuration',
      ]),
      'The following data can be transferred: Scooter settings, Keycards and Cloud configuration.',
    );
  });
}
