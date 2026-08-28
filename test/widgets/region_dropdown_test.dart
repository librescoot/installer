import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';

/// The region list is long: every German state plus the other countries, with
/// a disabled header row before each country. Opening it in an 800px window
/// has to leave a menu that is on screen and can be scrolled to the end.
void main() {
  const headerPrefix = '__country__';

  List<DropdownMenuItem<Region>> items(List<Region> regions) {
    final out = <DropdownMenuItem<Region>>[];
    String? country;
    for (final r in regions) {
      if (r.country != country) {
        country = r.country;
        out.add(DropdownMenuItem<Region>(
          enabled: false,
          value: Region(name: r.country, slug: '$headerPrefix${r.country}'),
          child: Text(r.country),
        ));
      }
      out.add(DropdownMenuItem<Region>(value: r, child: Text(r.name)));
    }
    return out;
  }

  /// The same field where it actually lives: last thing in a phase body,
  /// under a title bar, above an action bar, inside the body's scroll view.
  testWidgets('inside a phase it still opens onto the window', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final regions = Region.all;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PhaseLayout(
          title: 'Willkommen beim Librescoot Installer',
          subtitle: 'Dieser Assistent führt dich durch die Installation.',
          actions: const [PhaseAction(label: 'Installation starten', primary: true)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 8; i++) const SizedBox(height: 40),
              const Text('Region'),
              const SizedBox(height: 8),
              DropdownButtonFormField<Region>(
                initialValue: regions.first,
                items: items(regions),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(DropdownButton<Region>));
    await tester.pumpAndSettle();

    final menu = find.byType(Scrollable).last;
    final box = tester.getRect(menu);
    expect(box.top, greaterThanOrEqualTo(0),
        reason: 'menu starts above the top of the window: $box');
    expect(box.bottom, lessThanOrEqualTo(800),
        reason: 'menu runs past the bottom of the window: $box');

    final last = regions.last;
    await tester.dragUntilVisible(
      find.text(last.name),
      menu,
      const Offset(0, -60),
    );
    expect(find.text(last.name), findsWidgets);
  });

  testWidgets('the open menu stays inside the window and scrolls',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final regions = Region.all;
    // The catalogue is what makes this worth testing at all.
    expect(regions.length, greaterThan(15));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          // Roughly where the field sits on the welcome screen: low in the
          // window, which is what pushes the menu up over the title.
          padding: const EdgeInsets.only(top: 470, left: 330, right: 40),
          child: DropdownButtonFormField<Region>(
            initialValue: regions.first,
            items: items(regions),
            onChanged: (_) {},
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(DropdownButton<Region>));
    await tester.pumpAndSettle();

    // The menu is a route above everything, so it may cover the title. What it
    // may not do is put its content out of reach.
    final menu = find.byType(Scrollable).last;
    final box = tester.getRect(menu);
    expect(box.top, greaterThanOrEqualTo(0),
        reason: 'menu starts above the top of the window');
    expect(box.bottom, lessThanOrEqualTo(800),
        reason: 'menu runs past the bottom of the window');

    // And the last entry has to be reachable.
    final last = regions.last;
    await tester.dragUntilVisible(
      find.text(last.name),
      menu,
      const Offset(0, -60),
    );
    expect(find.text(last.name), findsWidgets);
  });
}
