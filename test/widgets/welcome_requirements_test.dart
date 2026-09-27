import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/widgets/welcome_requirements.dart';
import 'package:optimal_wrap_text/optimal_wrap_text.dart';

import '../goldens/font_harness.dart';

void main() {
  setUpAll(loadRealFonts);
  for (final locale in [const Locale('de'), const Locale('en')]) {
    testWidgets(
      'requirements are compact and link to the shop and video in ${locale.languageCode}',
      (tester) async {
        final opened = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                child: WelcomeRequirements(onOpenUrl: opened.add),
              ),
            ),
          ),
        );

        expect(find.byType(OptimalWrapRichText), findsOneWidget);
        final paragraph = tester.widget<Text>(
          find
              .descendant(
                of: find.byType(WelcomeRequirements),
                matching: find.byType(Text),
              )
              .first,
        );
        final underlinedTools = (paragraph.textSpan! as TextSpan).children!
            .whereType<TextSpan>()
            .where(
              (span) => span.style?.decoration == TextDecoration.underline,
            );
        expect(underlinedTools, hasLength(3));
        final copy = paragraph.textSpan!.toPlainText();
        expect(
          copy,
          contains(
            locale.languageCode == 'de'
                ? 'für das Fußbrett'
                : 'for the footboard',
          ),
        );
        expect(
          copy,
          contains(
            locale.languageCode == 'de'
                ? 'Verschraubung des DBC-Kabels'
                : "DBC cable's mounting screw",
          ),
        );
        expect(
          copy,
          contains(
            locale.languageCode == 'de'
                ? 'Admin-Rechte auf dem Computer'
                : 'administrator rights on your computer',
          ),
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('shop-link')),
            matching: find.byIcon(Icons.open_in_new),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(WelcomeRequirements),
                      matching: find.byType(Text),
                    )
                    .first,
              )
              .height,
          lessThan(75),
        );

        await tester.tap(find.byKey(const ValueKey('shop-link')));
        await tester.tap(find.byKey(const ValueKey('installation-video')));
        expect(opened, [
          WelcomeRequirements.shopUrl,
          locale.languageCode == 'en'
              ? 'https://downloads.librescoot.org/en/installation-video/'
              : 'https://downloads.librescoot.org/installation-video/',
        ]);
      },
    );
  }
}
