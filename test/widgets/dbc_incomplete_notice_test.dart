import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/dbc_incomplete_notice.dart';

void main() {
  testWidgets('keeps the incomplete result and retained details visible', (
    tester,
  ) async {
    var detailsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DbcIncompleteNotice(
            title: 'DBC installation incomplete',
            body: 'The requested DBC firmware was not verified.',
            detailsLabel: 'Show details',
            onShowDetails: () => detailsOpened = true,
          ),
        ),
      ),
    );

    expect(find.text('DBC installation incomplete'), findsOneWidget);
    expect(
      find.text('The requested DBC firmware was not verified.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Show details'));
    expect(detailsOpened, isTrue);
  });
}
