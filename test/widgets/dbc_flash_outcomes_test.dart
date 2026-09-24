import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('ERROR'), findsOneWidget);
    expect(find.text('SUCCESS'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('SUCCESS'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
