import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

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
          image: const _PulsingDbcLedImage(),
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

class _PulsingDbcLedImage extends StatefulWidget {
  const _PulsingDbcLedImage();

  @override
  State<_PulsingDbcLedImage> createState() => _PulsingDbcLedImageState();
}

class _PulsingDbcLedImageState extends State<_PulsingDbcLedImage>
    with SingleTickerProviderStateMixin {
  static const imageWidth = 2467.0;
  static const imageHeight = 2136.0;
  static const ledCenter = Offset(2260, 1007);
  static const ledDiameter = 6.0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  late final Animation<double> _brightness = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween<double>(0), weight: 20),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    TweenSequenceItem(tween: ConstantTween<double>(0), weight: 20),
  ]).animate(_pulse);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: imageWidth / imageHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxHeight / imageHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/dbc-flash-error-off.png',
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
              // Source artwork is 2467×2136; the LED centre is (2260, 1007).
              Positioned(
                left: ledCenter.dx * scale - ledDiameter / 2,
                top: ledCenter.dy * scale - ledDiameter / 2,
                child: AnimatedBuilder(
                  animation: _brightness,
                  builder: (context, child) {
                    final glow = const Color(
                      0xFFFF0000,
                    ).withValues(alpha: _brightness.value);
                    return Container(
                      key: const Key('dbc-error-led-glow'),
                      width: ledDiameter,
                      height: ledDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glow,
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(
                              alpha: _brightness.value * 0.8,
                            ),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
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
