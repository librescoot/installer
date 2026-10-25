import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/widgets/dashboard_handoff_signal_guide.dart';

void main() {
  testWidgets('shows the waiting and recognized LED states with ring motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 1000,
            child: SingleChildScrollView(child: DashboardHandoffSignalGuide()),
          ),
        ),
      ),
    );

    expect(find.text('Warten auf DBC'), findsOneWidget);
    expect(find.text('DBC erkannt'), findsOneWidget);
    expect(
      find.text('LED blinkt orange · Leuchtring pulsiert'),
      findsOneWidget,
    );
    expect(
      find.text('LED leuchtet dauerhaft orange · Leuchtring aus'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Klicke auf Weiter, sobald die Dashboard-LED dauerhaft orange leuchtet.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('handoff-scooter-ring-pulse')), findsOneWidget);
    expect(
      find.byKey(const Key('handoff-dashboard-amber-led')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const Key('handoff-dashboard-full-dbc-asset')),
      findsNWidgets(2),
    );
    final dbcGraphic = tester.getRect(
      find.byKey(const Key('handoff-dashboard-full-dbc-asset')).first,
    );
    final scooterGraphic = tester.getRect(
      find.byKey(const Key('handoff-scooter-ring-pulse')).first,
    );
    final indicator = tester.getRect(
      find.byKey(const Key('handoff-dashboard-amber-led')).first,
    );
    final card = tester.getRect(
      find
          .ancestor(
            of: find.text('Warten auf DBC'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(indicator.width, 6);
    expect(indicator.height, 6);
    expect(dbcGraphic.height, 104);
    expect(scooterGraphic.width, 57);
    expect(scooterGraphic.height, 108);
    expect(dbcGraphic.right + 10, closeTo(scooterGraphic.left, 0.1));
    expect(
      (dbcGraphic.left + scooterGraphic.right) / 2,
      closeTo(card.center.dx, 0.1),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
