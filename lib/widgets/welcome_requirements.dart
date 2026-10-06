import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

class WelcomeRequirements extends StatelessWidget {
  const WelcomeRequirements({super.key, required this.onOpenUrl});

  final ValueChanged<String> onOpenUrl;

  static const shopUrl =
      'https://shop.librescoot.org/product/mini-usb-kabel-mdb/';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: Colors.grey.shade300,
    );
    final videoUrl = l10n.localeName.startsWith('en')
        ? 'https://downloads.librescoot.org/en/installation-video/'
        : 'https://downloads.librescoot.org/installation-video/';

    final shopLink = WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: InkWell(
        key: const ValueKey('shop-link'),
        onTap: () => onOpenUrl(shopUrl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.requirementsShopLink,
              style: style.copyWith(
                color: kAccent,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.open_in_new, size: 12, color: kAccent),
          ],
        ),
      ),
    );

    final paragraph = Column(
      key: const ValueKey('requirements-list'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ${l10n.requirementsIntro}', style: style),
        Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: '• ${l10n.prerequisiteUsbCable} ('),
              shopLink,
              const TextSpan(text: ')'),
            ],
          ),
        ),
        Text('• ${l10n.prerequisiteScrewdriverPH2}', style: style),
        Text('• ${l10n.prerequisiteScrewdriverFlat}', style: style),
        Text('• ${l10n.requirementsOutro}', style: style),
      ],
    );

    final videoCard = SizedBox(
      width: 132,
      height: 66,
      child: Semantics(
        button: true,
        label: l10n.requirementsVideoLink,
        onTap: () => onOpenUrl(videoUrl),
        child: Material(
          color: const Color(0xFF242424),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: kAccent.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('installation-video'),
            excludeFromSemantics: true,
            onTap: () => onOpenUrl(videoUrl),
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: kAccent,
                    size: 25,
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l10n.requirementsVideoLink,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kAccent,
                        fontSize: 12,
                        height: 1.2,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              paragraph,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: videoCard),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: paragraph),
            const SizedBox(width: 16),
            videoCard,
          ],
        );
      },
    );
  }
}
