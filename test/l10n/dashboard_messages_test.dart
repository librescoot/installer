import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/dashboard_messages.dart';

/// These reach the vehicle as arguments inside a double-quoted shell command,
/// so a quote or a backslash in one of them does not misrender: it ends the
/// argument early and the script fails on the scooter, with the laptop
/// already unplugged.
///
/// They are also the only strings on a board whose operator has no screen to
/// read, so a language falling back to English without anyone noticing is
/// worth failing a build over.
void main() {
  Future<DashboardMessages> messagesFor(WidgetTester tester, Locale locale) async {
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
    return DashboardMessages(
      banner: l10n.dbcSayBanner,
      installing: l10n.dbcSayInstalling,
      installed: l10n.dbcSayInstalled,
      running: l10n.dbcSayRunning(DashboardMessages.versionToken),
      maps: l10n.dbcSayMaps,
      routing: l10n.dbcSayRouting,
      failed: l10n.dbcSayFailed,
      swap1: l10n.dbcSaySwap1,
      swap2: l10n.dbcSaySwap2,
      done: l10n.dbcSayDone,
      failOnboot: l10n.dbcSayFailOnboot,
      failDbc: l10n.dbcSayFailDbc,
      failTiles: l10n.dbcSayFailTiles(DashboardMessages.tileErrorsToken),
    );
  }

  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('every line survives the shell in ${locale.languageCode}',
        (tester) async {
      final messages = await messagesFor(tester, locale);
      messages.placeholders.forEach((placeholder, value) {
        expect(value.trim(), isNotEmpty, reason: '$placeholder is empty');
        for (final forbidden in ['"', r'\', '`', '\n']) {
          expect(value, isNot(contains(forbidden)),
              reason: '$placeholder carries $forbidden');
        }
        // A stray $ is a variable the vehicle expands to nothing, or worse.
        final dollars = r'$'.allMatches(value).length;
        final tokens = DashboardMessages.versionToken.allMatches(value).length +
            DashboardMessages.tileErrorsToken.allMatches(value).length;
        expect(dollars, tokens, reason: '$placeholder has an unexpected \$');
      });
    });

    testWidgets('the script still fills what it counts in ${locale.languageCode}',
        (tester) async {
      final messages = await messagesFor(tester, locale);
      expect(messages.running, contains(DashboardMessages.versionToken));
      expect(messages.failTiles, contains(DashboardMessages.tileErrorsToken));
    });
  }

  testWidgets('German is not English with a German label on it', (tester) async {
    // A missing key in app_de.arb generates the English string rather than
    // failing, so the only thing that catches one is the value.
    final en = await messagesFor(tester, const Locale('en'));
    final de = await messagesFor(tester, const Locale('de'));
    en.placeholders.forEach((placeholder, english) {
      expect(de.placeholders[placeholder], isNot(english),
          reason: '$placeholder was never translated');
    });
  });
}
