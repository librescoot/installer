import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/models/install_time_estimate.dart';
import 'package:librescoot_installer/widgets/handoff_duration.dart';

void main() {
  for (final bytes in [null, 110000000]) {
    testWidgets(
      'handoff duration never advances or reports completion (size=$bytes)',
      (tester) async {
        final estimate = InstallTimeEstimate.forAutonomousHandoff(
          plan: const InstallPlan(
            mdb: BoardPlan(board: Board.mdb, action: BoardAction.leave),
            dbc: BoardPlan(board: Board.dbc, action: BoardAction.upgrade),
          ),
          assets: InstallEstimateAssets(dbcArtifactBytes: bytes),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: HandoffDuration(estimate: estimate)),
          ),
        );
        final before = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .toList();
        expect(find.textContaining('ab dauerhaft orange'), findsOneWidget);
        expect(find.textContaining('nicht auslesen'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tester.pump(const Duration(hours: 2));
        expect(
          tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .toList(),
          before,
        );
        expect(find.textContaining('Noch etwa'), findsNothing);
        expect(find.textContaining('abgeschlossen'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
