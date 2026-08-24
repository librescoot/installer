@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/instruction_step.dart';
import 'package:librescoot_installer/widgets/phase_layout.dart';

import 'font_harness.dart';

/// The pairing screen, which was an icon, an address and two buttons in an
/// otherwise empty window.
void main() {
  setUpAll(loadRealFonts);

  testWidgets('bluetooth pairing, idle', (tester) async {
    tester.view.physicalSize = const Size(982, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBgPrimary),
      home: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          body: PhaseLayout(
            title: l10n.bluetoothPairingHeading,
            subtitle: l10n.bluetoothPairingHint,
            actions: [
              PhaseAction(label: l10n.skipPairing),
              PhaseAction(
                  label: l10n.startPairing,
                  icon: Icons.bluetooth_searching,
                  primary: true),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.blePairingWhy,
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade300)),
                const SizedBox(height: 20),
                InstructionStep(
                    number: 1,
                    title: l10n.blePairingStep1,
                    description: l10n.blePairingStep1Desc),
                InstructionStep(
                    number: 2,
                    title: l10n.blePairingStep2,
                    description: l10n.blePairingStep2Desc),
                InstructionStep(
                    number: 3,
                    title: l10n.blePairingStep3,
                    description: l10n.blePairingStep3Desc),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.link_off, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.blePairingOneAtATime,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${l10n.bleMacLabel}: ',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400)),
                      const Text('E0:23:A7:DF:93:53',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ));

    await expectLater(
      find.byType(PhaseLayout),
      matchesGoldenFile('pairing_idle.png'),
    );
  });
}
