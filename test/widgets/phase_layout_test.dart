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

  testWidgets('footer notice stays beside the action while body scrolls',
      (tester) async {
    tester.view.physicalSize = const Size(500, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(PhaseLayout(
      title: 'Welcome',
      footerLeading: const Text('Admin access for MDB storage and networking'),
      actions: [PhaseAction(
        label: 'Start installation',
        icon: Icons.shield_outlined,
        primary: true,
        onPressed: () {},
      )],
      child: Column(children: [for (var i = 0; i < 60; i++) Text('line $i')]),
    )));

    final notice = find.text('Admin access for MDB storage and networking');
    final button = find.widgetWithText(FilledButton, 'Start installation');
    expect(tester.getRect(notice).bottom, lessThanOrEqualTo(300));
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(300));
    expect(tester.getCenter(notice).dx, lessThan(tester.getCenter(button).dx));
    expect(find.descendant(of: button, matching: find.byIcon(Icons.shield_outlined)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phase buttons and back navigation log the visible choice',
      (tester) async {
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      await tester.pumpWidget(host(PhaseLayout(
        title: 'Dashboard work',
        onBack: () {},
        backLabel: 'Previous',
        actions: [PhaseAction(label: 'Skip to finish', onPressed: () {})],
        child: const Text('body'),
      )));

      await tester.tap(find.text('Skip to finish'));
      await tester.tap(find.text('Previous'));
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(messages, containsAllInOrder([
      'Journey: {"event":"button_pressed","screen":"Dashboard work","label":"Skip to finish","side":"forward"}',
      'Journey: {"event":"button_pressed","screen":"Dashboard work","label":"Previous","side":"back"}',
    ]));
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

  testWidgets('four German keycard-review actions fit a narrow bar',
      (tester) async {
    // The labels the keycard review stage actually shows in German -- the
    // combination that overflowed a plain Row.
    tester.view.physicalSize = const Size(700, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const PhaseLayout(
      title: 'A phase',
      actions: [
        PhaseAction(
            label: 'Von vorn beginnen',
            icon: Icons.refresh,
            side: ActionSide.back),
        PhaseAction(
            label: 'Anlernkarte hinzufügen', icon: Icons.shield_outlined),
        PhaseAction(label: 'Starten', icon: Icons.nfc),
        PhaseAction(label: 'Weiter', icon: Icons.arrow_forward, primary: true),
      ],
      child: Text('body'),
    )));

    expect(tester.takeException(), isNull);
    for (final label in [
      'Von vorn beginnen',
      'Anlernkarte hinzufügen',
      'Starten',
      'Weiter',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('German configured-keycard actions fit a narrow bar',
      (tester) async {
    tester.view.physicalSize = const Size(700, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const PhaseLayout(
      title: 'Schlüsselkarten',
      actions: [
        PhaseAction(label: 'Von vorn beginnen', icon: Icons.refresh),
        PhaseAction(label: 'Weitere hinzufügen', icon: Icons.nfc),
        PhaseAction(
          label: 'Anlernkarte hinzufügen (fortgeschritten)',
          icon: Icons.shield_outlined,
        ),
        PhaseAction(label: 'Fertig', icon: Icons.arrow_forward, primary: true),
      ],
      child: Text('body'),
    )));

    expect(tester.takeException(), isNull);
    for (final label in [
      'Von vorn beginnen',
      'Weitere hinzufügen',
      'Anlernkarte hinzufügen (fortgeschritten)',
      'Fertig',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
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
