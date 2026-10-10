import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/services/installer_sounds.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/models/installer_phase.dart';
import 'package:librescoot_installer/widgets/phase_sidebar.dart';

import '../goldens/font_harness.dart';

/// The sidebar is the only thing on screen for the whole install, so its
/// labels have to survive the language they are read in.
void main() {
  // Without this every glyph is a fixed-width box, roughly half again as wide
  // as the real face: any width measured here would be a measurement of a
  // font the app never uses, and this file is all about widths.
  setUpAll(loadRealFonts);
  tearDown(() => InstallerSounds.muted.value = false);

  Widget host(Widget child, {Locale locale = const Locale('de')}) =>
      MaterialApp(
        theme: librescootTheme(),
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

  testWidgets('the foot of the column fits in both languages', (tester) async {
    for (final locale in [const Locale('de'), const Locale('en')]) {
      await tester.pumpWidget(
        host(
          const PhaseSidebar(
            currentPhase: InstallerPhase.welcome,
            completedPhases: {},
          ),
          locale: locale,
        ),
      );
      await tester.pump();
      // An overflow paints a striped banner and, in a test, throws. The log
      // label is the one that has to survive; the language name may shorten.
      expect(
        tester.takeException(),
        isNull,
        reason: '${locale.languageCode}: the footer row overflowed',
      );
      // With both children at their natural size and no flex sibling to eat
      // the room, an overflow is the only way a label gets cut. A painter
      // comparison here would measure the fallback face, not what the widget
      // just drew, which is how this file came to report a problem the app
      // did not have.
    }
  });

  testWidgets('footer toggles sound for the whole session', (tester) async {
    for (final locale in [const Locale('de'), const Locale('en')]) {
      InstallerSounds.muted.value = false;
      await tester.pumpWidget(
        host(
          const PhaseSidebar(
            currentPhase: InstallerPhase.welcome,
            completedPhases: {},
          ),
          locale: locale,
        ),
      );
      final enabled = locale.languageCode == 'de'
          ? 'Ton ausschalten'
          : 'Mute sounds';
      final disabled = locale.languageCode == 'de'
          ? 'Ton einschalten'
          : 'Unmute sounds';
      expect(find.byTooltip(enabled), findsOneWidget);
      expect(find.text(enabled), findsNothing);
      await tester.tap(find.byTooltip(enabled));
      await tester.pump();
      expect(InstallerSounds.muted.value, isTrue);
      expect(find.byTooltip(disabled), findsOneWidget);
      await tester.tap(find.byTooltip(disabled));
      await tester.pump();
      expect(InstallerSounds.muted.value, isFalse);
      expect(tester.takeException(), isNull);
    }
  });
}
