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

  testWidgets('Stabil is recommended, and metadata aligns across cards', (
    tester,
  ) async {
    await tester.pumpWidget(host(selected: DownloadChannel.testing));
    expect(find.text('EMPFOHLEN'), findsOneWidget);
    expect(find.byType(OptimalWrapText), findsNWidgets(3));
    expect(
      find.text(
        'Testversionen für das nächste Release, ohne Stabilitätsgarantie, nur für technisch versierte Tester*innen empfohlen',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Täglich neu, nur für Entwickler*innen empfohlen'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final tags = ['v1.4.1', 'v1.5.0-beta.1', '2026.09.25'];
    final top = tags
        .map((tag) => tester.getTopLeft(find.text(tag)).dy)
        .toList();
    expect(top[0], top[1]);
    expect(top[1], top[2]);
    final dates = ['2026-09-27', '2026-09-26', '2026-09-25'];
    final dateTop = dates
        .map((date) => tester.getTopLeft(find.text(date)).dy)
        .toList();
    expect(dateTop[0], dateTop[1]);
    expect(dateTop[1], dateTop[2]);
  });

  testWidgets('nightly selection is distinct from the stable recommendation', (
    tester,
  ) async {
    await tester.pumpWidget(host(selected: DownloadChannel.nightly));
    expect(find.text('AUSGEWÄHLT'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    final stable = find.byKey(const ValueKey('channel-stable'));
    expect(
      tester.getSize(find.byKey(const ValueKey('channel-nightly'))).height,
      lessThan(170),
    );
    expect(
      find.descendant(of: stable, matching: find.text('EMPFOHLEN')),
      findsOneWidget,
    );
    final selected =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('channel-nightly-surface')),
                )
                .decoration!
            as BoxDecoration;
    final recommended =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('channel-stable-surface')),
                )
                .decoration!
            as BoxDecoration;
    expect(selected.border, Border.all(color: kAccent, width: 2));
    expect(selected.color, kAccent.withValues(alpha: 0.12));
    expect(recommended.border, Border.all(color: kOutline));
    expect(recommended.color, Colors.transparent);
    final badge = tester.widget<Text>(find.text('EMPFOHLEN'));
    expect(badge.style!.color, kTextMuted);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('other confirmations inherit the dialog width cap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: librescootTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm'),
                content: Text(
                  List.filled(20, 'Long confirmation text').join(' '),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final surface = find
        .ancestor(of: find.text('Confirm'), matching: find.byType(Material))
        .first;
    expect(tester.getSize(surface).width, lessThanOrEqualTo(600));
  });

  testWidgets('recommended badge and English copy are localized', (
    tester,
  ) async {
    await tester.pumpWidget(host(locale: const Locale('en')));
    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(find.text('SELECTED'), findsNothing);
    expect(
      find.text(
        'Test builds for the next release, with no stability guarantee; recommended only for technically experienced testers',
      ),
      findsOneWidget,
    );
  });
}
