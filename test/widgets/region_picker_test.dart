import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';
import 'package:librescoot_installer/widgets/region_picker.dart';

void main() {
  const alpha = Region(name: 'Alpha', slug: 'alpha', country: 'Deutschland');
  const zulu = Region(name: 'Zulu', slug: 'zulu', country: 'Deutschland');
  const belgium = Region(name: 'Belgien', slug: 'belgium', country: 'Belgien');
  const france = Region(
    name: 'Île-de-France',
    slug: 'france',
    country: 'Frankreich',
  );
  final regions = [france, zulu, belgium, alpha];

  testWidgets('country tabs group unsorted input into alphabetical pills', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegionPicker(
            regions: regions,
            selectedRegion: null,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(TabBar), findsOneWidget);
    final tabs = tester.widget<TabBar>(find.byType(TabBar)).tabs;
    expect(tabs.map((tab) => (tab as Tab).text), [
      'Deutschland',
      'Belgien',
      'Frankreich',
    ]);
    final pills = tester.widget<Wrap>(
      find.byKey(const ValueKey('region-pills')),
    );
    expect(
      pills.children.map((pill) => ((pill as ChoiceChip).label as Text).data),
      ['Alpha', 'Zulu'],
    );
    expect(find.byKey(const ValueKey('region-belgium')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('country-Belgien')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('region-belgium')), findsOneWidget);
    expect(find.byKey(const ValueKey('region-alpha')), findsNothing);
  });

  testWidgets('selecting a pill and browsing countries retains the selection', (
    tester,
  ) async {
    Region? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, refresh) => RegionPicker(
              regions: regions,
              selectedRegion: selected,
              onSelected: (region) => refresh(() => selected = region),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('region-zulu')));
    await tester.pumpAndSettle();
    expect(selected, zulu);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('region-zulu')))
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('country-Belgien')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('country-Deutschland')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('region-zulu')))
          .selected,
      isTrue,
    );
  });

  testWidgets('preselection and external changes open the matching country', (
    tester,
  ) async {
    Region? selected = france;
    late StateSetter refresh;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return RegionPicker(
                regions: regions,
                selectedRegion: selected,
                onSelected: (region) => setState(() => selected = region),
              );
            },
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('region-france')), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);

    refresh(() => selected = alpha);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('region-alpha')), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
  });

  testWidgets('the phase and compact dialog keep every region reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhaseLayout(
            title: 'Willkommen beim Librescoot Installer',
            subtitle: 'Wähle die Offline-Karten.',
            actions: const [
              PhaseAction(label: 'Installation starten', primary: true),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 320),
                const Text('Region'),
                RegionPicker(
                  regions: Region.all,
                  selectedRegion: null,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('region-thueringen')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const ValueKey('region-thueringen'))).bottom,
      lessThanOrEqualTo(800),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AlertDialog(
              title: const Text('Offline-Karten ändern'),
              content: SizedBox(
                width: 460,
                child: RegionPicker(
                  regions: Region.all,
                  selectedRegion: null,
                  maxRegionHeight: 240,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final scrollable = find.byType(SingleChildScrollView);
    expect(scrollable, findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('region-thueringen')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const ValueKey('region-thueringen'))).bottom,
      lessThanOrEqualTo(800),
    );
  });
}
