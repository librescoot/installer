@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/models/region.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';
import 'package:librescoot_installer/widgets/region_picker.dart';

import 'font_harness.dart';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('country tabs and selected region pills in a phase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(982, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
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
                const SizedBox(height: 230),
                const Text('Region'),
                const SizedBox(height: 8),
                RegionPicker(
                  regions: Region.all,
                  selectedRegion: Region.all[12],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('region_picker.png'),
    );
  });
}
