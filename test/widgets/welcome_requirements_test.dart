import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/widgets/welcome_requirements.dart';

import '../goldens/font_harness.dart';

void main() {
  setUpAll(loadRealFonts);
  for (final language in ['de', 'en']) {
    for (final width in [400.0, 620.0, 800.0, 1100.0]) {
      testWidgets(
        '$language requirements list fits at $width and preserves links',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final opened = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  child: WelcomeRequirements(onOpenUrl: opened.add),
                ),
              ),
            ),
          );
          final list = find.byKey(const ValueKey('requirements-list'));
          final rows = tester
              .widgetList<Text>(
                find.descendant(of: list, matching: find.byType(Text)),
              )
              .map((text) => text.data ?? text.textSpan!.toPlainText())
              .where((text) => text.startsWith('•'))
              .toList();
          expect(rows, hasLength(5));
          expect(rows.join('\n'), contains('PH2'));
          expect(rows.join('\n'), contains('H4'));
          expect(rows.join('\n'), contains('PH1'));
          final listRect = tester.getRect(list);
          final video = find.byKey(const ValueKey('installation-video'));
          final videoRect = tester.getRect(video);
          expect(videoRect.width, greaterThanOrEqualTo(280));
          expect(videoRect.width / videoRect.height, closeTo(16 / 9, 0.01));
          expect(
            find.byKey(const ValueKey('installation-video-thumbnail')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: video,
              matching: find.byIcon(Icons.open_in_new),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: video,
              matching: find.byIcon(Icons.play_circle_fill_rounded),
            ),
            findsOneWidget,
          );
          if (width >= 620) {
            expect(videoRect.left, greaterThan(listRect.right));
            expect(
              tester.getSize(find.byType(WelcomeRequirements)).height,
              lessThanOrEqualTo(240),
            );
          } else {
            expect(videoRect.top, greaterThan(listRect.bottom));
            expect(videoRect.right, lessThanOrEqualTo(width));
          }
          final videoText = find.descendant(
            of: video,
            matching: find.byType(Text),
          );
          expect(
            tester.renderObject<RenderParagraph>(videoText).didExceedMaxLines,
            isFalse,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('shop-link')));
          await tester.tap(video);
          expect(opened, [
            WelcomeRequirements.shopUrl,
            language == 'en'
                ? 'https://downloads.librescoot.org/en/installation-video/'
                : 'https://downloads.librescoot.org/installation-video/',
          ]);
        },
      );
    }
  }
}
