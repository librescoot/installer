@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/action_overlay.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';
import 'package:librescoot_installer/widgets/wait_scaffold.dart';

import 'font_harness.dart';

/// The unlock gate over the screen it interrupts.
void main() {
  setUpAll(loadRealFonts);

  testWidgets('the unlock gate', (tester) async {
    tester.view.physicalSize = const Size(982, 610);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: librescootTheme(),
      home: Scaffold(
        body: WaitScaffold(
          backdrop: PhaseLayout(
            title: 'Physische Vorbereitung',
            subtitle: 'Bereite deinen Roller für die USB-Verbindung vor.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('1  Fußraumabdeckung entfernen'),
                SizedBox(height: 24),
                Text('2  USB-Kabel vom MDB lösen'),
              ],
            ),
          ),
          overlay: ActionOverlay(
            title: 'Roller entsperren',
            instruction: 'Entsperre den Roller, damit der Installer '
                'weitermachen kann.',
            hints: const [
              'Schlüsselkarte an den Leser am Lenker halten',
              'Oder ein gekoppeltes Handy benutzen',
            ],
            watching: 'Der Installer macht automatisch weiter, sobald der '
                'Roller entsperrt ist.',
            actions: [
              TextButton(onPressed: () {}, child: const Text('Abbrechen')),
            ],
          ),
        ),
      ),
    ));
    // Far enough into the spinner's cycle to draw an arc rather than the dot
    // it starts as.
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('unlock_overlay.png'),
    );
  });
}
