@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librescoot_installer/l10n/app_localizations.dart';
import 'package:librescoot_installer/theme.dart';
import 'package:librescoot_installer/widgets/notice_card.dart';

import 'font_harness.dart';

/// The two notices every run shows before anything is written.
void main() {
  setUpAll(loadRealFonts);

  for (final locale in const [Locale('de'), Locale('en')]) {
    testWidgets('the pre-install notices in ${locale.languageCode}',
        (tester) async {
      tester.view.physicalSize = const Size(900, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: librescootTheme(),
        home: Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          final (lead, bullets, _) =
              NoticeCard.splitBullets(l10n.reliabilityWarningBody);
          final (dangerLead, dangerBullets, dangerWhy) =
              NoticeCard.splitBullets(l10n.noPowerCycleWarningBody);
          return Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.noticesHeading,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(l10n.noticesSubheading,
                      style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 20),
                  NoticeCard(
                    severity: NoticeSeverity.danger,
                    title: l10n.noPowerCycleWarningTitle,
                    body: dangerLead,
                    bullets: dangerBullets,
                    trail: dangerWhy,
                    footer: TextButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.chat_bubble_outline,
                          size: 16, color: Colors.red.shade200),
                      label: Text(l10n.openLibrescootDiscord,
                          style: TextStyle(color: Colors.red.shade200)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  NoticeCard(
                    severity: NoticeSeverity.warning,
                    title: l10n.reliabilityWarningTitle,
                    body: lead,
                    bullets: bullets,
                  ),
                ],
              ),
            ),
          );
        }),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('notices_${locale.languageCode}.png'));
    });
  }
}
