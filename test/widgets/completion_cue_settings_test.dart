import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/widgets/completion_cue_settings.dart';

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets('completion sound is explicit opt-in ($locale)', (
      tester,
    ) async {
      var sound = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CompletionCueSettings(
                  soundEnabled: sound,
                  onChanged: (value) => setState(() => sound = value),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(sound, isTrue);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(sound, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the choice is read-only once it has been staged', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: CompletionCueSettings(soundEnabled: true, onChanged: null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(tile.onChanged, isNull);
    expect(tile.value, isTrue);
  });
}
