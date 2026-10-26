import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/dashboard_handoff_signal_guide.dart';
import 'package:librescoot_installer/widgets/notice_card.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';
import 'package:librescoot_installer/widgets/preparation_step.dart';

void main() {
  testWidgets('fits the handoff instructions in an 800px desktop window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        theme: librescootTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: const Key('handoff-desktop-window'),
          child: Scaffold(
            body: PhaseLayout(
              title: 'USB-Kabel umstecken',
              subtitle:
                  'Laptop-Verbindung getrennt. Den weiteren Status erkennst du an den Signalen am Roller.',
              actions: [
                PhaseAction(
                  label: 'Weiter',
                  icon: Icons.arrow_forward,
                  primary: true,
                  onPressed: () {},
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PreparationStep(
                    number: 1,
                    title: 'Laptop-USB-Kabel abziehen',
                    description:
                        'Ziehe das Laptop-USB-Kabel am Hauptcomputer (MDB) ab.',
                    images: [
                      'assets/images/lsi-mdb_usb_laptop.jpg',
                      'assets/images/lsi-mdb_usb_dbc.jpg',
                    ],
                    imageLabels: ['Laptop-Kabel', 'Dashboard-Kabel'],
                    imageHeight: 115,
                  ),
                  const PreparationStep(
                    number: 2,
                    title: 'Internes Dashboard-Kabel anschließen',
                    description:
                        'Stecke das interne Dashboard-Kabel in denselben Anschluss. Ziehe die beiden Schrauben am Stecker wieder fest.',
                  ),
                  const NoticeCard(
                    severity: NoticeSeverity.info,
                    title: 'Installation auf dem Dashboard (DBC)',
                    body:
                        'Lass das interne USB-Kabel nach dem Umstecken angeschlossen.',
                  ),
                  const SizedBox(height: 12),
                  const DashboardHandoffSignalGuide(compact: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(
      find.byKey(const Key('handoff-desktop-window')),
    );
    await tester.runAsync(() async {
      for (final asset in [
        'assets/images/lsi-mdb_usb_laptop.jpg',
        'assets/images/lsi-mdb_usb_dbc.jpg',
        'assets/images/dbc-flash-error-off.png',
        'assets/images/dbc-flash-success-front-off.png',
        'assets/images/dbc-flash-success-front.png',
      ]) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final continueHint = find.text(
      'Klicke auf Weiter, sobald das Wartepulsieren endet.',
    );
    expect(continueHint, findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);
    expect(tester.getRect(continueHint).bottom, lessThanOrEqualTo(800));
    expect(tester.getRect(find.text('Weiter')).bottom, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

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
      find.text('Klicke auf Weiter, sobald das Wartepulsieren endet.'),
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
    expect(scooterGraphic.width, 176);
    expect(scooterGraphic.height, 128);
    final scooterArt = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('handoff-scooter-ring-pulse')),
        matching: find.byType(Image),
      ),
    );
    expect(scooterArt.fit, BoxFit.cover);
    expect(scooterArt.alignment, const Alignment(0, -0.33));
    expect(dbcGraphic.right + 10, closeTo(scooterGraphic.left, 0.1));
    expect(
      (dbcGraphic.left + scooterGraphic.right) / 2,
      closeTo(card.center.dx, 0.1),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
