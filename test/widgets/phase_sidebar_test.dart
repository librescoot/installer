import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/models/installer_phase.dart';
import 'package:librescoot_installer/l10n/phase_l10n.dart';
import 'package:librescoot_installer/widgets/phase_sidebar.dart';

/// The sidebar is the only thing on screen for the whole install, so its
/// labels have to survive the language they are read in.
void main() {
  Widget host(Widget child, {Locale locale = const Locale('de')}) => MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Row(children: [child])),
      );

  testWidgets('step titles fit on one line in both languages', (tester) async {
    await tester.pumpWidget(host(const PhaseSidebar(
      currentPhase: InstallerPhase.welcome,
      completedPhases: {},
    )));

    // The budget is the 300 sidebar minus 16+16 padding, the 18px marker and
    // the 10px gap after it. Measured in the weight the active step uses,
    // which is the widest a title ever gets.
    for (final locale in [const Locale('de'), const Locale('en')]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final step in MajorStep.values) {
        for (final upgrade in [false, true]) {
          final painter = TextPainter(
            text: TextSpan(
              text: step.localizedTitle(l10n, upgrade: upgrade),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          expect(painter.width, lessThanOrEqualTo(240),
              reason: '${locale.languageCode}/${step.name} wraps in the sidebar');
        }
      }
    }
  });

  testWidgets('a skipped step says so without wrecking its title',
      (tester) async {
    await tester.pumpWidget(host(const PhaseSidebar(
      currentPhase: InstallerPhase.welcome,
      completedPhases: {},
      skippedPhases: {
        InstallerPhase.dbcPrep,
        InstallerPhase.dbcFlash,
        InstallerPhase.reconnect,
      },
    )));

    // The word is its own line. Bracketed onto the end of the title it pushed
    // the title into a second, ragged line.
    expect(find.text('übersprungen'), findsOneWidget);
    expect(find.textContaining('(übersprungen)'), findsNothing);
  });

  testWidgets('the download chips speak the window language', (tester) async {
    final items = [
      DownloadItem(
        type: DownloadItemType.osmTiles,
        url: 'https://example.invalid/a',
        filename: 'a',
        expectedSize: 100,
      ),
      DownloadItem(
        type: DownloadItemType.mdbArtifact,
        url: 'https://example.invalid/b',
        filename: 'b',
        expectedSize: 100,
      ),
    ];

    await tester.pumpWidget(host(PhaseSidebar(
      currentPhase: InstallerPhase.welcome,
      completedPhases: const {},
      downloadItems: items,
    )));

    expect(find.text('Karten'), findsOneWidget);
    expect(find.text('MDB-Artefakt'), findsOneWidget);
    expect(find.text('Maps'), findsNothing);
  });
}
