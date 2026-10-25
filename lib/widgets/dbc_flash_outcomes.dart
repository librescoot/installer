import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'dbc_led_image.dart';

class DbcFlashOutcomes extends StatelessWidget {
  const DbcFlashOutcomes({
    super.key,
    required this.onError,
    required this.onSuccess,
    this.errorDescription,
    this.successDescription,
  });

  final VoidCallback onError;
  final VoidCallback? onSuccess;
  final String? errorDescription;
  final String? successDescription;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final error = _card(
          label: l10n.dbcFlashErrorLabel,
          description: errorDescription ?? l10n.dbcFlashErrorPrompt,
          color: Colors.redAccent,
          onPressed: onError,
          image: const DbcLedImage(
            color: Color(0xFFFF0000),
            indicatorKey: Key('dbc-error-led-glow'),
          ),
        );
        final success = _card(
          label: l10n.dbcFlashSuccessLabel,
          description: successDescription ?? l10n.dbcFlashSuccessPrompt,
          color: Colors.greenAccent,
          onPressed: onSuccess,
          image: const _LightingSuccessImage(),
        );
        if (constraints.maxWidth < 660) {
          return Column(children: [error, const SizedBox(height: 16), success]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 8, child: error),
            const SizedBox(width: 16),
            Expanded(flex: 12, child: success),
          ],
        );
      },
    );
  }

  Widget _card({
    required String label,
    required String description,
    required Color color,
    required VoidCallback? onPressed,
    required Widget image,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 370,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: 0.06),
          side: BorderSide(color: color.withValues(alpha: 0.65), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: image)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The success pictures with their lights coming on: the lit artwork fades in
/// over the unlit one, holds, and fades out again.
class _LightingSuccessImage extends StatefulWidget {
  const _LightingSuccessImage();

  @override
  State<_LightingSuccessImage> createState() => _LightingSuccessImageState();
}

class _LightingSuccessImageState extends State<_LightingSuccessImage>
    with SingleTickerProviderStateMixin {
  // 500 ms fade in, 1.5 s on, 250 ms fade out, 500 ms off.
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2750),
  )..repeat();

  late final Animation<double> _lit = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 500),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 1500),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 250),
    TweenSequenceItem(tween: ConstantTween<double>(0), weight: 500),
  ]).animate(_cycle);

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  Widget _layered(String name, double width) {
    Widget image(String path) => Image.asset(
      path,
      width: width,
      height: 230,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    return Stack(
      children: [
        image('assets/images/dbc-flash-success-$name-off.png'),
        FadeTransition(
          key: Key('dbc-success-$name-lit'),
          opacity: _lit,
          child: image('assets/images/dbc-flash-success-$name.png'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Each off image has the same canvas as its lit counterpart, so the
    // layers line up without offsets.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _layered('side', 230 * 3537 / 2181),
          const SizedBox(width: 8),
          _layered('front', 230 * 1124 / 2159),
        ],
      ),
    );
  }
}
