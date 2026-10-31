import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'requirements_preview_row.dart';

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

    final videoCard = LayoutBuilder(
      builder: (context, constraints) => Semantics(
        button: true,
        label: l10n.requirementsVideoLink,
        onTap: () => onOpenUrl(videoUrl),
        child: Material(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Ink.image(
            key: const ValueKey('installation-video-thumbnail'),
            image: const AssetImage('assets/images/installation-video.webp'),
            fit: BoxFit.cover,
            child: InkWell(
              key: const ValueKey('installation-video'),
              excludeFromSemantics: true,
              onTap: () => onOpenUrl(videoUrl),
              child: ExcludeSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xDD000000)],
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.15),
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: constraints.maxHeight < 100 ? 32 : 40,
                        shadows: const [
                          Shadow(blurRadius: 12, color: Colors.black87),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.open_in_new,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 6,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.requirementsVideoLink,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
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
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(width: 132, height: 66, child: videoCard),
              ),
            ],
          );
        }
        return RequirementsPreviewRow(list: paragraph, preview: videoCard);
      },
    );
  }
}
