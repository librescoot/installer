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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: kAccent,
          onPrimary: kOnAccent,
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
              const SizedBox(height: 260),
              const Text('Region'),
              const SizedBox(height: 8),
              DropdownMenu<Region>(
                width: 420,
                menuHeight: 400,
                initialSelection: null,
                leadingIcon: Icon(Icons.place_outlined,
                    size: 20, color: Colors.grey.shade400),
                enableFilter: false,
                requestFocusOnTap: false,
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: kBgSidebar,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                ),
                menuStyle: MenuStyle(
                  backgroundColor: const WidgetStatePropertyAll(kBgSidebar),
                  surfaceTintColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  elevation: const WidgetStatePropertyAll(12),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22)),
                    ),
                  ),
                  padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 6)),
                ),
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
