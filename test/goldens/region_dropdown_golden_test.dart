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

  testWidgets('the region menu, open', (tester) async {
    tester.view.physicalSize = const Size(982, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final regions = Region.all;
    List<DropdownMenuEntry<Region>> entries() {
      final out = <DropdownMenuEntry<Region>>[];
      String? country;
      for (final r in regions) {
        if (r.country != country) {
          country = r.country;
          out.add(DropdownMenuEntry<Region>(
            value: Region(name: r.country, slug: '__c__${r.country}'),
            label: r.country.toUpperCase(),
            enabled: false,
            style: MenuItemButton.styleFrom(
              foregroundColor: kAccent.withValues(alpha: 0.75),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                height: 2.0,
              ),
            ),
          ));
        }
        out.add(DropdownMenuEntry<Region>(
          value: r,
          label: r.name,
          style: MenuItemButton.styleFrom(
            padding: const EdgeInsets.only(left: 28, right: 16),
          ),
        ));
      }
      return out;
    }

    await tester.pumpWidget(MaterialApp(
      theme: librescootTheme(),
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
              const SizedBox(height: 260),
              const Text('Region'),
              const SizedBox(height: 8),
              DropdownMenu<Region>(
                width: 420,
                menuHeight: 400,
                // A selection, so the golden also covers the row the menu
                // marks as selected.
                initialSelection: Region.all[12],
                leadingIcon: Icon(Icons.place_outlined,
                    size: 20, color: Colors.grey.shade400),
                enableFilter: false,
                requestFocusOnTap: false,
                dropdownMenuEntries: entries(),
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('region_menu_open.png'),
    );
  });
}
