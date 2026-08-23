import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';

/// The actions bar is where an install is confirmed, so it must be reachable
/// on a window too short for the body. It used to scroll with the content,
/// which put the one control that commits to an irreversible write below the
/// fold with nothing to say it was there.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('actions stay on screen and tappable in a short window',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var continued = false;
    await tester.pumpWidget(host(PhaseLayout(
      title: 'A phase',
      actions: [
        PhaseAction(
          label: 'Continue',
          primary: true,
          onPressed: () => continued = true,
        ),
      ],
      child: Column(
        children: [for (var i = 0; i < 60; i++) Text('line $i')],
      ),
    )));

    final button = find.widgetWithText(FilledButton, 'Continue');
    expect(button, findsOneWidget);
    await tester.tap(button);
    expect(continued, isTrue,
        reason: 'the action bar must not scroll away with the body');
  });

  testWidgets('carrying on goes right, leaving goes left', (tester) async {
    await tester.pumpWidget(host(PhaseLayout(
      title: 'A phase',
      actions: [
        // Deliberately listed with the forward action first, to prove the
        // order comes from meaning rather than from the list.
        const PhaseAction(label: 'Continue', primary: true),
        const PhaseAction(label: 'Skip'),
        const PhaseAction(label: 'Cancel', side: ActionSide.back),
      ],
      child: const Text('body'),
    )));

    double xOf(String label) => tester.getCenter(find.text(label)).dx;

    // Skip carries on with the install, so it belongs with Continue on the
    // right, not next to Cancel.
    expect(xOf('Cancel'), lessThan(xOf('Skip')));
    expect(xOf('Skip'), lessThan(xOf('Continue')));
  });

  testWidgets('a secondary action still looks like a button', (tester) async {
    await tester.pumpWidget(host(const PhaseLayout(
      title: 'A phase',
      actions: [PhaseAction(label: 'Skip')],
      child: Text('body'),
    )));

    // Bare text was unrecognisable as a control next to a filled primary.
    expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);
  });

  testWidgets('a custom action is placed but not restyled', (tester) async {
    await tester.pumpWidget(host(PhaseLayout(
      title: 'A phase',
      actions: [
        PhaseAction.custom(
          primary: true,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.check),
            label: const Text('Bespoke'),
          ),
        ),
        const PhaseAction(label: 'Back out', side: ActionSide.back),
      ],
      child: const Text('body'),
    )));

    expect(find.widgetWithText(FilledButton, 'Bespoke'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      tester.getCenter(find.text('Back out')).dx,
      lessThan(tester.getCenter(find.text('Bespoke')).dx),
    );
  });

  testWidgets('the title stays put while the body scrolls', (tester) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(PhaseLayout(
      title: 'Stays put',
      child: Column(
        children: [for (var i = 0; i < 80; i++) Text('line $i')],
      ),
    )));

    final before = tester.getTopLeft(find.text('Stays put')).dy;
    await tester.drag(find.text('line 5'), const Offset(0, -200));
    await tester.pump();
    expect(tester.getTopLeft(find.text('Stays put')).dy, before);
  });
}
