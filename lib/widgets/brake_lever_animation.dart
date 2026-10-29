import 'package:flutter/material.dart';

enum BrakeLeverPose { released, held, rightReleased }

/// The timer selects each movement; the sprite never runs its own gesture loop.
class BrakeLeverAnimation extends StatefulWidget {
  const BrakeLeverAnimation({
    super.key,
    required this.pose,
    this.animate = true,
  });

  final BrakeLeverPose pose;
  final bool animate;

  @override
  State<BrakeLeverAnimation> createState() => _BrakeLeverAnimationState();
}

class _BrakeLeverAnimationState extends State<BrakeLeverAnimation> {
  static const _framesPerMovement = 12;
  static const _movementDuration = Duration(milliseconds: 440);
  int _firstFrame = 0;
  int _lastFrame = 0;

  int _restingFrame(BrakeLeverPose pose) => switch (pose) {
    BrakeLeverPose.released => 0,
    BrakeLeverPose.held => 11,
    BrakeLeverPose.rightReleased => 23,
  };

  @override
  void initState() {
    super.initState();
    _firstFrame = _lastFrame = _restingFrame(widget.pose);
  }

  @override
  void didUpdateWidget(BrakeLeverAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose == widget.pose && oldWidget.animate == widget.animate) {
      return;
    }
    final movement = switch ((oldWidget.pose, widget.pose)) {
      (BrakeLeverPose.released, BrakeLeverPose.held) => 0,
      (BrakeLeverPose.held, BrakeLeverPose.rightReleased) => 1,
      (BrakeLeverPose.rightReleased, BrakeLeverPose.held) => 2,
      (BrakeLeverPose.held, BrakeLeverPose.released) => 3,
      _ => null,
    };
    if (!widget.animate || movement == null) {
      _firstFrame = _lastFrame = _restingFrame(widget.pose);
    } else {
      _firstFrame = movement * _framesPerMovement;
      _lastFrame = _firstFrame + _framesPerMovement - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final animate = widget.animate && !MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        key: ValueKey((widget.pose, animate)),
        tween: Tween(
          begin: animate ? _firstFrame.toDouble() : _lastFrame.toDouble(),
          end: _lastFrame.toDouble(),
        ),
        duration: animate ? _movementDuration : Duration.zero,
        builder: (context, frame, _) => BrakeLeverFrame(frame: frame.round()),
      ),
    );
  }
}

class BrakeLeverFrame extends StatelessWidget {
  const BrakeLeverFrame({super.key, required this.frame})
    : assert(frame >= 0 && frame < 48);

  static const asset = 'assets/images/brake-levers.webp';
  static const aspectRatio = 790 / 174;
  final int frame;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: width * 4,
            maxWidth: width * 4,
            minHeight: height * 12,
            maxHeight: height * 12,
            child: Transform.translate(
              offset: Offset(-(frame % 4) * width, -(frame ~/ 4) * height),
              child: Image.asset(
                asset,
                width: width * 4,
                height: height * 12,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        );
      },
    ),
  );
}
