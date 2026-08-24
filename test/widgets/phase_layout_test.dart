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

  testWidgets('the title and the actions read as bars, not as body',
      (tester) async {
    await tester.pumpWidget(host(const PhaseLayout(
      title: 'A phase',
      actions: [PhaseAction(label: 'Continue', primary: true)],
      child: Text('body'),
    )));

    // Both bars carry the same tint and hairline, which is what separates
    // them from the page. Without it the title floats above the body and the
    // buttons read as if they belonged to whatever text sits above them.
    final tinted = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) {
          final d = c.decoration;
          return d is BoxDecoration && d.color == kBarTint;
        })
        .length;
    expect(tinted, 2, reason: 'expected a tinted title bar and action bar');
  });

  testWidgets('the body is not penned into a narrow column', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const PhaseLayout(
      title: 'A phase',
      child: SizedBox(width: double.infinity, height: 40, child: Text('body')),
    )));

    // A 720-wide cap in a 1280 window left a gutter on both sides wide enough
    // to read as a design mistake.
    expect(tester.getSize(find.text('body')).width, greaterThan(900));
  });

  testWidgets('the title starts where the body starts', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const PhaseLayout(
      title: 'Short',
      subtitle: 'A subtitle that is quite a bit longer than the title itself',
      child: Align(alignment: Alignment.centerLeft, child: Text('body')),
    )));

    // A shrink-wrapped header centres itself as a block, which reads as a
    // centred heading that happens to be left-aligned inside. Every line
    // shares one left edge instead.
    final left = tester.getTopLeft(find.text('Short')).dx;
    expect(tester.getTopLeft(find.text('A subtitle that is quite a bit longer '
        'than the title itself')).dx, left);
    expect(tester.getTopLeft(find.text('body')).dx, left);
  });

  testWidgets('every phase gets the same measure', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<Rect> render(String title, Widget body) async {
      await tester.pumpWidget(host(PhaseLayout(title: title, child: body)));
      return tester.getRect(find.text(title));
    }

    // The layout owns the width. A screen that could pass its own ended up
    // centred in a column of its own, so its title, body and buttons each
    // started somewhere different from the screen before it.
    final wide = await render('One',
        const SizedBox(width: double.infinity, height: 40, child: Text('a')));
    final narrow = await render('Two', const SizedBox(width: 80, height: 40));

    expect(narrow.left, wide.left);
  });

  testWidgets('content starts at the top, however little of it there is',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // One line of content used to float in the middle of the window on some
    // screens and sit under the title on others, depending on a flag each
    // screen set for itself.
    await tester.pumpWidget(host(const PhaseLayout(
      title: 'A phase',
      child: Text('one line'),
    )));
    final short = tester.getTopLeft(find.text('one line')).dy;

    await tester.pumpWidget(host(PhaseLayout(
      title: 'A phase',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('one line'),
          for (var i = 0; i < 40; i++) Text('filler $i'),
        ],
      ),
    )));
    final long = tester.getTopLeft(find.text('one line')).dy;

    expect(short, long,
        reason: 'the first line belongs in the same place either way');
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
