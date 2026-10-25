import 'package:flutter/material.dart';

/// The DBC status LED drawn over the board artwork used by the outcome page.
class DbcLedImage extends StatefulWidget {
  const DbcLedImage({
    super.key,
    required this.color,
    this.pulsing = true,
    this.indicatorKey,
    this.assetKey,
  });

  final Color color;
  final bool pulsing;
  final Key? indicatorKey;
  final Key? assetKey;

  @override
  State<DbcLedImage> createState() => _DbcLedImageState();
}

class _DbcLedImageState extends State<DbcLedImage>
    with SingleTickerProviderStateMixin {
  static const _imageWidth = 2467.0;
  static const _imageHeight = 2136.0;
  static const _ledCenter = Offset(2260, 1007);
  static const _ledDiameter = 6.0;

  late final AnimationController? _pulse = widget.pulsing
      ? (AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat())
      : null;

  late final Animation<double>? _brightness = _pulse == null
      ? null
      : TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween<double>(0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
          TweenSequenceItem(tween: ConstantTween<double>(1), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
          TweenSequenceItem(tween: ConstantTween<double>(0), weight: 20),
        ]).animate(_pulse);

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  Widget _indicator(double brightness) {
    final glow = widget.color.withValues(alpha: brightness);
    return Container(
      key: widget.indicatorKey,
      width: _ledDiameter,
      height: _ledDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: glow,
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: brightness * 0.8),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _imageWidth / _imageHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxHeight / _imageHeight;
          final led = Positioned(
            left: _ledCenter.dx * scale - _ledDiameter / 2,
            top: _ledCenter.dy * scale - _ledDiameter / 2,
            child: _brightness == null
                ? _indicator(1)
                : AnimatedBuilder(
                    animation: _brightness,
                    builder: (context, child) => _indicator(_brightness.value),
                  ),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/dbc-flash-error-off.png',
                  key: widget.assetKey,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
              led,
            ],
          );
        },
      ),
    );
  }
}
