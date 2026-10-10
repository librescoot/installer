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

  Widget host({String? error}) =>
      MaterialApp(
        theme: librescootTheme(),
        locale: const Locale('de'),
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

}
