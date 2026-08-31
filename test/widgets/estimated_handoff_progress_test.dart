import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/board_state.dart';
import 'package:librescoot_installer/models/install_plan.dart';
import 'package:librescoot_installer/models/install_time_estimate.dart';
import 'package:librescoot_installer/widgets/estimated_handoff_progress.dart';

void main() {
  test('the bar agrees with the countdown and never claims completion', () {
    // Half the typical time elapsed reads as half done, matching the
    // remaining-minutes text beside it.
    expect(
      estimatedHandoffFraction(
        elapsed: const Duration(minutes: 5),
        typical: const Duration(minutes: 10),
        conservativeUpper: const Duration(minutes: 20),
        indeterminate: false,
      ),
      0.5,
    );
    expect(
      estimatedHandoffFraction(
        elapsed: const Duration(minutes: 10),
        typical: const Duration(minutes: 10),
        conservativeUpper: const Duration(minutes: 20),
        indeterminate: false,
      ),
      0.9,
    );
    expect(
      estimatedHandoffFraction(
        elapsed: const Duration(minutes: 19),
        typical: const Duration(minutes: 10),
        conservativeUpper: const Duration(minutes: 20),
        indeterminate: false,
      ),
      lessThanOrEqualTo(0.97),
    );
    expect(
      estimatedHandoffFraction(
        elapsed: const Duration(minutes: 20),
        typical: const Duration(minutes: 10),
        conservativeUpper: const Duration(minutes: 20),
        indeterminate: false,
      ),
      isNull,
      reason: 'elapsed time must never claim autonomous completion',
    );
  });

  test('unknown asset sizes never produce a numeric fraction', () {
    expect(
      estimatedHandoffFraction(
        elapsed: const Duration(minutes: 5),
        typical: const Duration(minutes: 10),
        conservativeUpper: const Duration(minutes: 30),
        indeterminate: true,
      ),
      isNull,
    );
  });

  testWidgets('German copy warns not to reconnect from the estimate', (
    tester,
  ) async {
    final plan = InstallPlan(
      mdb: const BoardPlan(board: Board.mdb, action: BoardAction.leave),
      dbc: const BoardPlan(board: Board.dbc, action: BoardAction.upgrade),
    );
    final estimate = InstallTimeEstimate.forAutonomousHandoff(
      plan: plan,
      assets: const InstallEstimateAssets(dbcArtifactBytes: 110000000),
    );
    final start = DateTime(2026, 8, 29, 12);

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
        home: Scaffold(
          body: EstimatedHandoffProgress(
            estimate: estimate,
            startedAt: start,
            now: () => start.add(const Duration(minutes: 2)),
          ),
        ),
      ),
    );

    expect(find.text('Geschätzter Fortschritt'), findsOneWidget);
    expect(find.textContaining('nicht aufgrund der Schätzung'), findsOneWidget);
    expect(find.textContaining('vergangen'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNotNull);
    expect(bar.value!, lessThan(0.5));
  });
}
