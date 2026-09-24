import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/widgets/dbc_flash_outcomes.dart';

void main() {
  testWidgets('both outcome graphics trigger their respective actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var errors = 0;
    var successes = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 900,
              child: DbcFlashOutcomes(
                onError: () => errors++,
                onSuccess: () => successes++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ERROR'), findsOneWidget);
    expect(find.text('SUCCESS'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));
    final side = tester.getRect(find.byType(Image).at(1));
    final front = tester.getRect(find.byType(Image).at(2));
    expect(front.height, closeTo(side.height, 0.1));
    final artwork = tester.getRect(find.byType(Image).first);
    final led = tester.getRect(find.byKey(const Key('dbc-error-led-glow')));
    expect(
      led.center.dx,
      closeTo(artwork.left + artwork.width * 2260 / 2467, 1),
    );
    expect(
      led.center.dy,
      closeTo(artwork.top + artwork.height * 1007 / 2136, 1),
    );
    Color ledColor() =>
        (tester
                    .widget<Container>(
                      find.byKey(const Key('dbc-error-led-glow')),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    final dim = ledColor().a;
    await tester.pump(const Duration(milliseconds: 250));
    expect(ledColor().a, greaterThan(dim));
    expect(ledColor().r, 1);
    expect(ledColor().g, 0);
    expect(ledColor().b, 0);
    await tester.pump(const Duration(milliseconds: 250));
    expect(ledColor().a, lessThan(1));
    expect(
      tester.getTopLeft(find.text('ERROR')).dy,
      tester.getTopLeft(find.text('SUCCESS')).dy,
    );
    expect(
      tester.getTopLeft(find.textContaining('DBC LED blinks red')).dy,
      tester.getTopLeft(find.textContaining('Scooter unlocked')).dy,
    );
    await tester.tap(find.text('ERROR'));
    await tester.tap(find.text('SUCCESS'));
    expect(errors, 1);
    expect(successes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow layout stacks choices and can disable success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          body: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: DbcFlashOutcomes(onError: () {}, onSuccess: null),
            ),
          ),
        ),
      ),
    );
    expect(find.text('FEHLER'), findsOneWidget);
    expect(find.text('ERFOLG'), findsOneWidget);
    expect(find.textContaining('DBC-LED blinkt rot'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('ERFOLG'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
