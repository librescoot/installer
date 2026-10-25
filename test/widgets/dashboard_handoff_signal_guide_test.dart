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

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
