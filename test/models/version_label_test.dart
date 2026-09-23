import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/models/version_label.dart';

void main() {
  test(
    'the health check names the same nightly with one channel and T case',
    () {
      final l10n = AppLocalizationsDe();
      expect(
        l10n.healthVersionPlan(
          installedVersionLabel('Librescoot', 'nightly-20260923t005854'),
          targetVersionLabel(
            'Librescoot',
            'nightly',
            'nightly-20260923T005854',
          ),
        ),
        'Aktuell installiert: Librescoot nightly-20260923T005854; '
        'zu installieren: Librescoot nightly-20260923T005854',
      );
    },
  );

  test('testing channel and timestamp are not repeated', () {
    expect(
      targetVersionLabel('Librescoot', 'testing', 'TESTING-20260923t005854'),
      'Librescoot testing-20260923T005854',
    );
  });

  test('stable version has no duplicate channel label', () {
    expect(
      targetVersionLabel('Librescoot', 'stable', 'v1.4.0'),
      'Librescoot v1.4.0',
    );
  });

  test('unknown versions still include the selected channel', () {
    expect(
      targetVersionLabel('Librescoot', 'nightly', 'custom-build'),
      'Librescoot nightly custom-build',
    );
    expect(installedVersionLabel('Bootstrap', ''), 'Bootstrap');
    expect(
      installedVersionLabel('unu scooterOS', '1.2.3'),
      'unu scooterOS 1.2.3',
    );
  });
}
