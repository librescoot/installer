import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/l10n/app_localizations_de.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/dashboard_preparation_notice.dart';
import 'package:optimal_wrap_text/optimal_wrap_text.dart';

import '../goldens/font_harness.dart';

void main() {
  setUpAll(loadRealFonts);

  Widget host({String? error, Locale locale = const Locale('de')}) =>
      MaterialApp(
        theme: librescootTheme(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SizedBox(
            width: 550,
            child: DashboardPreparationNotice(error: error),
          ),
        ),
      );

  testWidgets('preparation notice balances within its available width', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final notice = tester.widget<OptimalWrapText>(find.byType(OptimalWrapText));
    expect(notice.width, 550);
    expect(notice.textAlign, TextAlign.center);
    expect(
      find.text(AppLocalizationsDe().filesStagedWaitingForHandoff),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed preparation replaces progress copy and shows the reason',
    (tester) async {
      const error = 'Installer connection is not routed over USB';
      await tester.pumpWidget(host(error: error));
      expect(
        find.text(AppLocalizationsDe().filesStagedWaitingForHandoff),
        findsNothing,
      );
      expect(
        find.text(AppLocalizationsDe().handoffPreparationFailed),
        findsOneWidget,
      );
      expect(find.text(error), findsOneWidget);
      expect(
        tester
            .widget<OptimalWrapText>(find.byType(OptimalWrapText))
            .style!
            .color,
        kDanger,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(host());
      expect(find.text(error), findsNothing);
      expect(
        find.text(AppLocalizationsDe().filesStagedWaitingForHandoff),
        findsOneWidget,
      );
    },
  );

  testWidgets('English failure copy does not promise readiness', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(error: 'route lookup failed', locale: const Locale('en')),
    );
    expect(
      find.textContaining(
        'preparation for automatically waiting for the dashboard failed',
      ),
      findsOneWidget,
    );
    expect(find.text('route lookup failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
