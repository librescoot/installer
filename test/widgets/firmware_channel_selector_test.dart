import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/firmware_channel_selector.dart';
import 'package:optimal_wrap_text/optimal_wrap_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/font_harness.dart';

void main() {
  setUpAll(loadRealFonts);

  Widget host({
    Locale locale = const Locale('de'),
    DownloadChannel selected = DownloadChannel.stable,
    ValueChanged<DownloadChannel>? onSelected,
  }) => MaterialApp(
    theme: librescootTheme(),
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 900,
        child: FirmwareChannelSelector(
          channels: const {
            DownloadChannel.stable: (tag: 'v1.4.1', date: '2026-09-27'),
            DownloadChannel.testing: (tag: 'v1.5.0-beta.1', date: '2026-09-26'),
            DownloadChannel.nightly: (tag: '2026.09.25', date: '2026-09-25'),
          },
          selected: selected,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('Nightly requires consent once and remembers it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    DownloadChannel? selected;
    await tester.pumpWidget(host(onSelected: (channel) => selected = channel));

    await tester.tap(find.byKey(const ValueKey('channel-nightly')));
    await tester.pumpAndSettle();
    expect(find.text('Nightly wirklich auswählen?'), findsOneWidget);
    expect(find.byType(OptimalWrapRichText), findsOneWidget);
    final surface = find
        .ancestor(
          of: find.text('Nightly wirklich auswählen?'),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.getSize(surface).width, lessThanOrEqualTo(520));
    expect(tester.getSize(surface).height, lessThan(500));
    expect(find.textContaining('nicht nutzbar'), findsOneWidget);
    expect(
      find.textContaining('keinen Support für Nightly-Versionen'),
      findsOneWidget,
    );
    expect(selected, isNull);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(selected, isNull);

    await tester.tap(find.byKey(const ValueKey('channel-nightly')));
    await tester.pumpAndSettle();
    expect(find.text('Nightly wirklich auswählen?'), findsOneWidget);
    await tester.tap(find.text('Risiko verstanden, Nightly wählen'));
    await tester.pumpAndSettle();
    expect(selected, DownloadChannel.nightly);

    selected = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host(onSelected: (channel) => selected = channel));
    await tester.tap(find.byKey(const ValueKey('channel-nightly')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(selected, DownloadChannel.nightly);
  });
}
