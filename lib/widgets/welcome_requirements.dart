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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: l10n.requirementsIntro),
              TextSpan(
                text: l10n.prerequisiteScrewdriverPH2,
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
              TextSpan(text: l10n.requirementsFootwell),
              TextSpan(
                text: l10n.prerequisiteScrewdriverFlat,
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
              TextSpan(text: l10n.requirementsDbcCable),
              TextSpan(text: l10n.requirementsAnd),
              TextSpan(
                text: l10n.prerequisiteUsbCable,
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
              const TextSpan(text: ' ('),
              shopLink,
              const TextSpan(text: ')'),
              TextSpan(text: l10n.requirementsOutro),
            ],
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          key: const ValueKey('installation-video'),
          onPressed: () => onOpenUrl(videoUrl),
          icon: const Icon(Icons.play_circle_outline, size: 16),
          label: Text(l10n.requirementsVideoLink),
          style: TextButton.styleFrom(
            foregroundColor: kAccent,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
