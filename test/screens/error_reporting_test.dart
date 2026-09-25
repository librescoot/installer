import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/main.dart';

void main() {
  testWidgets('render-time errors show one banner after the frame', (
    tester,
  ) async {
    var reported = false;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              if (!reported) {
                reported = true;
                reportUnhandledError(StateError('layout failure'), null);
              }
              return const Text('Screen stays usable');
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Screen stays usable'), findsOneWidget);
    expect(find.textContaining('layout failure'), findsOneWidget);
  });
}
