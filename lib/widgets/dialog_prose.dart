import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:optimal_wrap_text/optimal_wrap_text.dart';

/// Balanced body copy within an AlertDialog's intrinsic layout.
class DialogProse extends StatelessWidget {
  const DialogProse(this.text, {super.key, this.style, this.maxWidth = 552});

  final String text;
  final TextStyle? style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => OptimalWrapText(
    text,
    width: math.max(
      1,
      math.min(maxWidth, MediaQuery.sizeOf(context).width - 128),
    ),
    shrinkWrap: true,
    style: style,
  );
}
