@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';

import 'font_harness.dart';

/// The region menu, open, in the app's own theme. Reported as "overlapped by
/// the step title and not scrollable", which a light-theme widget test does
/// not reproduce: what a menu looks like is a question about the theme.
void main() {
  setUpAll(loadRealFonts);

  List<DropdownMenuItem<Region>> items(List<Region> regions) {
    final out = <DropdownMenuItem<Region>>[];
    String? country;
    for (final r in regions) {
      if (r.country != country) {
        country = r.country;
        out.add(DropdownMenuItem<Region>(
          enabled: false,
          value: Region(name: r.country, slug: '__c__${r.country}'),
          child: Text(r.country,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600)),
        ));
      }
      out.add(DropdownMenuItem<Region>(
        value: r,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(r.name),
        ),
      ));
    }
    return out;
  }

  testWidgets('the region menu, open', (tester) async {
    tester.view.physicalSize = const Size(982, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final regions = Region.all;
    await tester.pumpWidget(MaterialApp(
      // The app's theme, which is the part a default-theme test misses.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: kAccent,
          onPrimary: kOnAccent,
          secondary: kAccent,
          onSecondary: kOnAccent,
          surface: kBgPrimary,
          onSurface: kTextPrimary,
        ),
        scaffoldBackgroundColor: kBgPrimary,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: PhaseLayout(
          title: 'Willkommen beim Librescoot Installer',
          subtitle: 'Dieser Assistent führt dich durch die Installation.',
          actions: const [
            PhaseAction(label: 'Installation starten', primary: true),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 300),
              const Text('Region'),
              const SizedBox(height: 8),
              DropdownButtonFormField<Region>(
                initialValue: regions.first,
                menuMaxHeight: 360,
                borderRadius: BorderRadius.circular(8),
                decoration: const InputDecoration(border: OutlineInputBorder()),
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

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('region_menu_open.png'),
    );
  });
}
