import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
void main() {
  test('the font and its licence ship with it', () {
    expect(File('assets/fonts/InterVariable.ttf').existsSync(), isTrue);
    // SIL OFL requires the licence travel with the font.
    final licence = File('assets/fonts/Inter-LICENSE.txt');
    expect(licence.existsSync(), isTrue);
    expect(licence.readAsStringSync(), contains('SIL Open Font License'));
  });
}
