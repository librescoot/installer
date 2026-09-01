import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/theme.dart';

/// The installer used to render in whatever each platform supplied, so the
/// same screen differed across Windows, macOS and Linux and the German strings
/// wrapped in different places.
void main() {
  test('the theme renders in the bundled family', () {
    expect(librescootTheme().textTheme.bodyMedium?.fontFamily, 'Inter');
  });

  test('the font and its licence ship with it', () {
    expect(File('assets/fonts/InterVariable.ttf').existsSync(), isTrue);
    // SIL OFL requires the licence travel with the font.
    final licence = File('assets/fonts/Inter-LICENSE.txt');
    expect(licence.existsSync(), isTrue);
    expect(licence.readAsStringSync(), contains('SIL Open Font License'));
  });

  test('pubspec declares it, which an asset entry alone does not do', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Inter'));
    expect(pubspec, contains('asset: assets/fonts/InterVariable.ttf'));
  });

  test('one variable file, not a pile of static weights', () {
    // It is smaller than the weights it replaces and covers the ones between.
    final size = File('assets/fonts/InterVariable.ttf').lengthSync();
    expect(size, lessThan(1200 * 1024), reason: 'unexpectedly large for one face');
    final declared = File('pubspec.yaml')
        .readAsLinesSync()
        .where((l) => l.contains('asset: assets/fonts/'))
        .length;
    expect(declared, 1, reason: 'a second face crept in');
  });

  test('monospace is still left to the platform', () {
    // Inter has no mono face, and the only monospace text is diagnostics the
    // user copies out.
    final source =
        File('lib/widgets/driver_blocked_panel.dart').readAsStringSync();
    expect(source, contains("fontFamily: 'monospace'"));
  });
}
