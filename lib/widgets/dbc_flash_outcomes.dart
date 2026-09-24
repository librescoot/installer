import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class DbcFlashOutcomes extends StatelessWidget {
  const DbcFlashOutcomes({
    super.key,
    required this.onError,
    required this.onSuccess,
  });

  final VoidCallback onError;
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final error = _card(
          label: l10n.dbcFlashErrorLabel,
          description: l10n.dbcFlashErrorPrompt,
          color: Colors.redAccent,
          onPressed: onError,
          image: const _PulsingDbcLedImage(),
        );
        final success = _card(
          label: l10n.dbcFlashSuccessLabel,
          description: l10n.dbcFlashSuccessPrompt,
          color: Colors.greenAccent,
          onPressed: onSuccess,
          image: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                flex: 4,
                child: Image.asset(
                  'assets/images/dbc-flash-success-side.png',
                  height: 210,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Image.asset(
                  'assets/images/dbc-flash-success-front.png',
                  height: 210,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        );
        if (constraints.maxWidth < 660) {
          return Column(children: [error, const SizedBox(height: 16), success]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: error),
            const SizedBox(width: 16),
            Expanded(child: success),
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
      height: 325,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: Text(
                description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
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
    duration: const Duration(milliseconds: 250),
  )..repeat(reverse: true);

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
                  animation: _pulse,
                  builder: (context, child) {
                    final glow = const Color(
                      0xFFFF0000,
                    ).withValues(alpha: _pulse.value);
                    return Container(
                      key: const Key('dbc-error-led-glow'),
                      width: ledDiameter,
                      height: ledDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glow,
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(alpha: _pulse.value * 0.8),
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
