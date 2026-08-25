import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';

/// Not knowing the root password is a different answer from changing your
/// mind, and it has a next step. The guidance has to name both places to look,
/// or the dead end is just a dead end.
void main() {
  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('the guidance says where to find it in ${locale.languageCode}',
        (tester) async {
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

      final body = l10n.manualPasswordUnknownBody;
      expect(body, contains('Discord'));
      // The workshop is the likelier source and the one nobody thinks of.
      expect(
        body.toLowerCase(),
        anyOf(contains('workshop'), contains('werkstatt')),
      );
      // It must say the scooter is untouched: someone at this screen has just
      // been told the installer cannot get in, and will assume the worst.
      expect(
        body.toLowerCase(),
        anyOf(contains('nothing on the scooter has been changed'),
            contains('nichts verändert')),
      );
      expect(l10n.manualPasswordUnknown, isNotEmpty);
      expect(l10n.manualPasswordUnknownHeading, isNotEmpty);
    });
  }
}
