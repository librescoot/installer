import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/l10n/phase_l10n.dart';
import 'package:librescoot_installer/models/installer_phase.dart';

/// The resume screen showed the stage as stored, which is the enum's own name:
/// "Zuletzt: dbcPrep" in an otherwise German UI. Every phase the run state can
/// record needs a title in both languages, or the identifier leaks again.
void main() {
  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('every phase has a title in ${locale.languageCode}',
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

      for (final phase in InstallerPhase.values) {
        final title = phase.localizedTitle(l10n);
        expect(title, isNotEmpty, reason: '${phase.name} has no title');
        expect(title, isNot(phase.name),
            reason: '${phase.name} renders as its own enum name');
      }
    });
  }
}
