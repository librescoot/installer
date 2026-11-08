import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/completion_cue.dart';

void main() {
  test('UI and device encode LIBRESCOOT identically', () {
    expect(completionMorseLetters, [
      '.-..',
      '..',
      '-...',
      '.-.',
      '.',
      '...',
      '-.-.',
      '---',
      '---',
      '-',
    ]);
    final worker = File('tool/completion-signal/show.go').readAsStringSync();
    expect(worker, contains('const morse = "${completionMorseLetters.join(' ')}"'));
    expect(completionMorseUnit, const Duration(milliseconds: 200));
    expect(completionLightCycle, const Duration(milliseconds: 20800));
    expect(completionLightSteps.last.lit, isFalse);
    expect(completionLightSteps.last.units, 7);
    expect(completionLightSteps.where((step) => step.lit), hasLength(28));
  });
}
