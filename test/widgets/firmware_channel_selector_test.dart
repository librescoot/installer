import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/models/download_state.dart';
import 'package:librescoot_installer/widgets/firmware_channel_selector.dart';

void main() {
  Widget host({
    Locale locale = const Locale('de'),
    DownloadChannel selected = DownloadChannel.stable,
    ValueChanged<DownloadChannel>? onSelected,
  }) => MaterialApp(
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
    expect(
      find.text('Vorschauversionen zum Testen, ohne Stabilitätsgarantie'),
      findsOneWidget,
    );
    expect(find.text('Täglich neu, nur für Entwickler*innen'), findsOneWidget);
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

  testWidgets('recommended badge and English copy are localized', (
    tester,
  ) async {
    await tester.pumpWidget(host(locale: const Locale('en')));
    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(
      find.text('Preview releases for testing, without a stability guarantee'),
      findsOneWidget,
    );
  });
}
