import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/l10n/phase_l10n.dart';
import 'package:librescoot_installer/models/installer_phase.dart';

/// needsHandoff is true for offline maps by themselves, so the dashboard block
/// runs for a plan that leaves the dashboard untouched and writes no firmware.
/// Every label on it said flash, which promises something it does not do.
void main() {
  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('the maps-only labels never say flash in ${locale.languageCode}',
        (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context)!;
          return const SizedBox.shrink();
        }),
      ));

      final labels = [
        MajorStep.dbcFlash.localizedTitle(l10n, mapsOnly: true),
        InstallerPhase.dbcPrep.localizedTitle(l10n, mapsOnly: true),
        InstallerPhase.dbcFlash.localizedTitle(l10n, mapsOnly: true),
        InstallerPhase.dbcPrep.localizedDescription(l10n, mapsOnly: true),
        InstallerPhase.dbcFlash.localizedDescription(l10n, mapsOnly: true),
      ];

      for (final label in labels) {
        expect(label, isNotEmpty);
        expect(label.toLowerCase(), isNot(contains('flash')));
      }
    });

    testWidgets('the firmware labels still say flash in ${locale.languageCode}',
        (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = AppLocalizations.of(context)!;
          return const SizedBox.shrink();
        }),
      ));

      // The real dashboard install keeps its own wording: it does write
      // firmware, and softening that would be the opposite mistake.
      expect(
        InstallerPhase.dbcFlash.localizedTitle(l10n).toLowerCase(),
        contains('flash'),
      );
    });
  }
}
