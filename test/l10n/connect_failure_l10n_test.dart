import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/l10n/connect_failure_l10n.dart';
import 'package:librescoot_installer/models/connect_failure.dart';

/// The connect screen used to show the caught exception and nothing else, so
/// its usefulness now lives entirely in this copy. A kind with no wording, a
/// German string left in English, or a checklist that lost its bullets all
/// take the screen back to where it was without failing anything else.
Future<AppLocalizations> _load(WidgetTester tester, Locale locale) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (context) {
      l10n = AppLocalizations.of(context)!;
      return const SizedBox.shrink();
    }),
  ));
  return l10n;
}

void main() {
  for (final locale in const [Locale('en'), Locale('de')]) {
    final tag = locale.languageCode;

    testWidgets('every failure has a heading and a body in $tag',
        (tester) async {
      final l10n = await _load(tester, locale);
      for (final kind in ConnectFailureKind.values) {
        expect(kind.heading(l10n), isNotEmpty, reason: '${kind.name} heading');
        expect(kind.body(l10n), isNotEmpty, reason: '${kind.name} body');
      }
    });

    testWidgets('the checklists keep their bullets in $tag', (tester) async {
      final l10n = await _load(tester, locale);
      for (final kind in ConnectFailureKind.values) {
        // The macOS permission is prose with a setting to open, and the panel
        // renders it as prose. Everything else is meant to be scannable, and
        // a body that loses its bullets silently reverts to a wall of text.
        if (kind == ConnectFailureKind.localNetworkBlocked) continue;
        expect(
          kind.body(l10n),
          contains('•'),
          reason: '${kind.name} has nothing for the checklist card',
        );
      }
    });

    testWidgets('a dead end says the scooter is untouched in $tag',
        (tester) async {
      final l10n = await _load(tester, locale);
      // Someone reading "the installer cannot reach your scooter" assumes the
      // worst about what it did before it stopped. These three stop the run,
      // so they are the ones that have to say it outright.
      for (final kind in const [
        ConnectFailureKind.authRejected,
        ConnectFailureKind.sshRefused,
        ConnectFailureKind.unknown,
      ]) {
        expect(
          kind.body(l10n).toLowerCase(),
          anyOf(
            contains('nothing on the scooter has been changed'),
            contains('nichts verändert'),
          ),
          reason: '${kind.name} leaves the user guessing',
        );
      }
    });

    testWidgets('the ones with no retry button explain themselves in $tag',
        (tester) async {
      final l10n = await _load(tester, locale);
      // Both keep an attempt running behind the screen, so neither offers a
      // Retry. Without a line saying the installer is still going, the screen
      // reads as a dead end with no way out of it.
      for (final kind in const [
        ConnectFailureKind.noUsbDevice,
        ConnectFailureKind.localNetworkBlocked,
      ]) {
        expect(
          kind.body(l10n).toLowerCase(),
          anyOf(
            contains('carries on by itself'),
            contains('macht von selbst weiter'),
            contains('macht von allein weiter'),
          ),
          reason: '${kind.name} never says the installer is still watching',
        );
      }
    });
  }

  testWidgets('German is German, not English left in place', (tester) async {
    final en = await _load(tester, const Locale('en'));
    final de = await _load(tester, const Locale('de'));
    for (final kind in ConnectFailureKind.values) {
      expect(kind.heading(de), isNot(kind.heading(en)),
          reason: '${kind.name} heading is still the English one');
      expect(kind.body(de), isNot(kind.body(en)),
          reason: '${kind.name} body is still the English one');
    }
  });

  test('no dashes anywhere in the new copy', () {
    // House rule for every string this app ships. A dash pasted in from a
    // draft renders as a stray glyph in Inter and reads as a typo.
    for (final arb in const ['lib/l10n/app_en.arb', 'lib/l10n/app_de.arb']) {
      for (final line in File(arb).readAsLinesSync()) {
        if (!line.trimLeft().startsWith('"connectFailed')) continue;
        expect(line, isNot(contains('—')), reason: 'em dash in $arb');
        expect(line, isNot(contains('–')), reason: 'en dash in $arb');
      }
    }
  });
}
