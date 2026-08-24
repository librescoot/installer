@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/wait_plan.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/wait_overlay.dart';
import 'package:librescoot_installer/widgets/wait_scaffold.dart';

import 'font_harness.dart';

/// Renders the wait as it is actually seen, to a file, in seconds. Run with
/// `flutter test --update-goldens test/goldens` and look at the result.
void main() {
  setUpAll(loadRealFonts);

  Widget app(Widget child) => MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBgPrimary),
        home: Scaffold(body: child),
      );

  /// Stands in for the screen the wait draws over.
  Widget backdrop() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Physische Vorbereitung',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: kAccent)),
            const SizedBox(height: 24),
            for (final line in [
              '1  Fußraumabdeckung entfernen',
              '2  USB-Kabel vom MDB lösen',
              '3  Laptop-USB-Kabel anschließen',
            ])
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(line, style: const TextStyle(fontSize: 15)),
              ),
          ],
        ),
      );

  final start = DateTime(2026, 8, 24, 12, 0, 0);

  testWidgets('the wait, mid-step', (tester) async {
    tester.view.physicalSize = const Size(982, 610);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(WaitScaffold(
      backdrop: backdrop(),
      overlay: WaitOverlay(
        title: 'MDB wird vorbereitet',
        steps: const [
          WaitStep(label: 'Fahrakku wird abgeschaltet', typical: Duration(seconds: 15)),
          WaitStep(label: 'Roller startet neu', typical: Duration(seconds: 60)),
          WaitStep(label: 'Warte auf UMS-Gerät', typical: Duration(seconds: 25)),
        ],
        currentStep: 1,
        startedAt: start,
        stepStartedAt: start.add(const Duration(seconds: 18)),
        warning: 'USB und Strom nicht trennen.',
        logTail: const ['12:00:03 Fahrakku wird abgeschaltet'],
        now: () => start.add(const Duration(seconds: 50)),
      ),
    )));

    await expectLater(
      find.byType(WaitScaffold),
      matchesGoldenFile('wait_overlay.png'),
    );
  });

  testWidgets('the wait, running long', (tester) async {
    tester.view.physicalSize = const Size(982, 610);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(WaitScaffold(
      backdrop: backdrop(),
      overlay: WaitOverlay(
        title: 'MDB-Update',
        steps: const [
          WaitStep(label: 'Artefakt wird übertragen', typical: Duration(seconds: 60)),
          WaitStep(label: 'Firmware wird installiert', typical: Duration(minutes: 2)),
          WaitStep(label: 'Installierte Version wird geprüft', typical: Duration(minutes: 2)),
        ],
        currentStep: 1,
        startedAt: start,
        stepStartedAt: start.add(const Duration(seconds: 55)),
        progress: 0.62,
        warning: 'USB und Strom nicht trennen.',
        now: () => start.add(const Duration(minutes: 4, seconds: 20)),
      ),
    )));

    await expectLater(
      find.byType(WaitScaffold),
      matchesGoldenFile('wait_overlay_overdue.png'),
    );
  });
}
