import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/version_label.dart';

void main() {
  test('installed and target nightly labels canonicalize the timestamp', () {
    const expected = 'Librescoot nightly-20260923T005854';
    expect(installedVersionLabel('Librescoot', 'nightly-20260923t005854'),
        expected);
    expect(
      targetVersionLabel('Librescoot', 'nightly', 'nightly-20260923T005854'),
      expected,
    );
  });

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
