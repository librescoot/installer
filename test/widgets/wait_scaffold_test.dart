import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/wait_scaffold.dart';

/// The wait draws over the screen the user just left. It only reads that way
/// if it actually fills the space: handed an unbounded height it collapsed to
/// the size of its card, which left the card in the top corner and the veil
/// painted only behind itself.
void main() {
  testWidgets('it fills the space it is given', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: WaitScaffold(
          backdrop: Text('the screen underneath'),
          overlay: SizedBox(width: 300, height: 160, child: Text('card')),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(WaitScaffold)), const Size(900, 600));
    // Centred, not parked in a corner.
    final card = tester.getCenter(find.text('card'));
    expect(card.dx, closeTo(450, 1));
    expect(card.dy, closeTo(300, 1));
  });

  testWidgets('the screen underneath is visible but out of reach',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WaitScaffold(
          backdrop: TextButton(
            onPressed: () => tapped = true,
            child: const Text('underneath'),
          ),
          overlay: const Text('card'),
        ),
      ),
    ));

    expect(find.text('underneath'), findsOneWidget);
    await tester.tap(find.text('underneath'), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isFalse, reason: 'a frozen screen must not take clicks');
  });
}
