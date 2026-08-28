import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/notice_card.dart';

void main() {
  group('splitBullets', () {
    test('a closing sentence lands after the list, not before it', () {
      // Hoisted above the bullets it reads as their introduction, which
      // inverts the meaning: the list is what not to do, the closing line is
      // why it matters.
      final (lead, bullets, trail) = NoticeCard.splitBullets(
        'Stop and ask first.\n• Do not pull AUX\n• Do not unplug USB\n'
        'The installer recovers from almost anything.',
      );
      expect(lead, 'Stop and ask first.');
      expect(bullets, ['Do not pull AUX', 'Do not unplug USB']);
      expect(trail, 'The installer recovers from almost anything.');
    });

    test('a plain checklist has no trailing prose', () {
      final (lead, bullets, trail) =
          NoticeCard.splitBullets('Check:\n• One\n• Two');
      expect(lead, 'Check:');
      expect(bullets, ['One', 'Two']);
      expect(trail, isNull);
    });

    test('text with no bullets stays entirely in the lead', () {
      final (lead, bullets, trail) = NoticeCard.splitBullets('Just prose.');
      expect(lead, 'Just prose.');
      expect(bullets, isEmpty);
      expect(trail, isNull);
    });
  });

  test('both notices carry a bullet list in both languages', () {
    // The copy is what makes these scannable; a translation that loses the
    // bullets silently reverts the screen to a wall of prose.
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_de.arb']) {
      final text = File(arb).readAsStringSync();
      for (final key in ['noPowerCycleWarningBody', 'reliabilityWarningBody']) {
        final line =
            text.split('\n').firstWhere((l) => l.contains('"$key":'));
        expect(line, contains(r'•'.replaceAll(r'•', '•')),
            reason: '$key in $arb lost its bullets');
      }
    }
  });
}
