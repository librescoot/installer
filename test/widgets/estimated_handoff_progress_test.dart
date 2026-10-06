import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/models/install_time_estimate.dart';
import 'package:librescoot_installer/widgets/estimated_handoff_progress.dart';

void main() {
  double? fraction(int minutes, {bool unknown = false}) =>
      estimatedHandoffFraction(
        elapsed: Duration(minutes: minutes),
        typical: const Duration(minutes: 10),
        conservativeUpper: const Duration(minutes: 20),
        indeterminate: unknown,
      );

  test('elapsed estimate never claims completion', () {
    expect(fraction(-1), 0);
    expect(fraction(5), 0.5);
    expect(fraction(10), 0.9);
    expect(fraction(19), lessThanOrEqualTo(0.97));
    expect(fraction(20), isNull);
    expect(fraction(25), isNull);
    expect(fraction(5, unknown: true), isNull);
  });

  testWidgets(
    'clock uses disconnection time and remains explicitly estimated',
    (tester) async {
      final estimate = InstallTimeEstimate.forAutonomousHandoff(
        plan: InstallPlan(
          mdb: const BoardPlan(board: Board.mdb, action: BoardAction.leave),
          dbc: const BoardPlan(board: Board.dbc, action: BoardAction.upgrade),
        ),
        assets: const InstallEstimateAssets(dbcArtifactBytes: 110000000),
      );
      final start = DateTime(2026);
      var now = start.add(const Duration(minutes: 2));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EstimatedHandoffProgress(
              estimate: estimate,
              startedAt: start,
              now: () => now,
            ),
          ),
        ),
      );
      expect(find.text('Seit Kabeltrennung: 2:00'), findsOneWidget);
      expect(find.textContaining('keine Live-Daten'), findsOneWidget);
      expect(find.textContaining('Geschätzt noch'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        lessThan(1),
      );
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Seit Kabeltrennung: 2:05'), findsOneWidget);
      now = start.add(const Duration(days: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(
        find.textContaining('Schätzung ist überschritten'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}
