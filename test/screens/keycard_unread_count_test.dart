import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A keycard count that has not been read must not render as zero.
///
/// The panel showed "0 cards taught" and offered "register at least one" while
/// it was still asking the board, which reads as an answer rather than a
/// question. A missing redis key, an unparseable value and a genuine zero were
/// all int 0.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/installer_screen.dart').readAsStringSync();
  });

  test('the counts are nullable, so unread survives to the render', () {
    expect(source, contains('int? _keycardMasterCount;'));
    expect(source, contains('int? _keycardAuthorizedCount;'));
  });

  test('a failed or absent read does not become zero', () {
    // int.tryParse(...) ?? 0 is what collapsed the three cases into one.
    expect(source, contains("_keycardAuthorizedCount = int.tryParse(a ?? '');"));
    expect(source, isNot(contains("int.tryParse(a ?? '') ?? 0")));
    expect(source, isNot(contains("int.tryParse(m ?? '') ?? 0")));
  });

  test('the panel says it is checking rather than showing a count', () {
    expect(source, contains('l10n.keycardCardsChecking'));
    expect(source, contains('cards == null'));
  });

  test('both languages carry the checking string', () {
    for (final arb in ['lib/l10n/app_en.arb', 'lib/l10n/app_de.arb']) {
      expect(File(arb).readAsStringSync(), contains('"keycardCardsChecking"'),
          reason: '$arb is missing it');
    }
  });
}
