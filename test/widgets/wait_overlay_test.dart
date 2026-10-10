import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/wait_plan.dart';
import 'package:librescoot_installer/widgets/wait_overlay.dart';

/// What someone in front of a wait actually wants to know is how long it
/// takes and whether this one is going wrong. The overlay has to answer both
/// without being asked.
void main() {
  final steps = [
    const WaitStep(label: 'UMS-Modus setzen', typical: Duration(seconds: 20)),
    const WaitStep(label: 'Roller startet neu', typical: Duration(minutes: 1)),
    const WaitStep(label: 'Gerät erscheint', typical: Duration(seconds: 20)),
  ];

  Widget host(Widget child) => MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      );

  final start = DateTime(2026, 8, 24, 12, 0, 0);

  testWidgets('a step running long says so instead of sitting there',
      (tester) async {
    await tester.pumpWidget(host(WaitOverlay(
      title: 'MDB wird vorbereitet',
      steps: steps,
      currentStep: 1,
      startedAt: start,
      stepStartedAt: start,
      // Two minutes into a step that usually takes one.
      now: () => start.add(const Duration(minutes: 2)),
    )));

    expect(find.textContaining('länger als üblich'), findsOneWidget);
  });

  testWidgets('the log is there but out of the way', (tester) async {
    await tester.pumpWidget(host(WaitOverlay(
      title: 'MDB wird vorbereitet',
      steps: steps,
      currentStep: 0,
      startedAt: start,
      now: () => start,
      logTail: const ['12:00:01 UMS-Modus gesetzt', '12:00:02 warte auf Gerät'],
    )));

    expect(find.text('12:00:01 UMS-Modus gesetzt'), findsNothing);
    await tester.tap(find.text('Protokoll anzeigen'));
    await tester.pump();
    expect(find.textContaining('UMS-Modus gesetzt'), findsOneWidget);
  });

  testWidgets('it survives being drawn before the steps are known',
      (tester) async {
    // The builder runs on the frame the work is scheduled, so the first
    // paint can land before the phase has said what its steps are. That used
    // to throw out of a clamp and show up as "Interner Fehler".
    await tester.pumpWidget(host(WaitOverlay(
      title: 'MDB wird verbunden',
      steps: const [],
      currentStep: 0,
      startedAt: start,
      now: () => start,
    )));

    expect(tester.takeException(), isNull);
    expect(find.text('MDB wird verbunden'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('download and transfer progress can run together',
      (tester) async {
    await tester.pumpWidget(host(WaitOverlay(
      title: 'MDB-Update',
      steps: const [
        WaitStep(
          label: 'Downloads werden abgeschlossen',
          typical: Duration(minutes: 3),
        ),
        WaitStep(
          label: 'Firmware übertragen',
          typical: Duration(minutes: 2),
        ),
      ],
      currentStep: 0,
      startedAt: start,
      progress: 0.4,
      backgroundLabel: 'Firmware übertragen',
      backgroundProgress: 0.2,
      now: () => start,
    )));

    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(bars.map((bar) => bar.value), containsAll([0.4, 0.2]));
    expect(find.text('Downloads werden abgeschlossen'), findsOneWidget);
    expect(find.text('Firmware übertragen'), findsWidgets);
  });
}
