import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Wraps children in the fewest rows, then distributes them evenly across rows.
class BalancedWrap extends MultiChildRenderObjectWidget {
  const BalancedWrap({
    super.key,
    super.children,
    this.spacing = 0,
    this.runSpacing = 0,
  });

  final double spacing;
  final double runSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderBalancedWrap(
    spacing: spacing,
    runSpacing: runSpacing,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBalancedWrap renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..textDirection = Directionality.of(context);
  }
}

class _BalancedWrapParentData extends ContainerBoxParentData<RenderBox> {}

class RenderBalancedWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BalancedWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BalancedWrapParentData> {
  RenderBalancedWrap({
    required double spacing,
    required double runSpacing,
    required TextDirection textDirection,
  }) : _spacing = spacing,
       _runSpacing = runSpacing,
       _textDirection = textDirection;

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get runSpacing => _runSpacing;
  double _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BalancedWrapParentData) {
      child.parentData = _BalancedWrapParentData();
    }
  }

  List<RenderBox> get _children {
    final result = <RenderBox>[];
    for (var child = firstChild; child != null; child = childAfter(child)) {
      result.add(child);
    }
    return result;
  }

  List<int> _rowEnds(List<Size> sizes, double maxWidth) {
    if (sizes.isEmpty) return [];
    if (!maxWidth.isFinite) return [sizes.length];

    var rows = 1;
    var used = 0.0;
    for (final child in sizes) {
      final next = used == 0 ? child.width : used + spacing + child.width;
      if (used > 0 && next > maxWidth) {
        rows++;
        used = child.width;
      } else {
        used = next;
      }
    }

    final n = sizes.length;
    final costs = List.generate(
      rows + 1,
      (_) => List.filled(n + 1, double.infinity),
    );
    final ends = List.generate(rows + 1, (_) => List.filled(n + 1, n));
    costs[0][n] = 0;
    for (var count = 1; count <= rows; count++) {
      for (var start = n - count; start >= 0; start--) {
        var width = 0.0;
        for (var end = start + 1; end <= n - count + 1; end++) {
          width += sizes[end - 1].width + (end == start + 1 ? 0 : spacing);
          if (end > start + 1 && width > maxWidth) break;
          final slack = math.max(0.0, maxWidth - width);
          final cost = slack * slack + costs[count - 1][end];
          if (cost < costs[count][start]) {
            costs[count][start] = cost;
            ends[count][start] = end;
          }
        }
      }
    }

    final result = <int>[];
    var start = 0;
    for (var count = rows; count > 0; count--) {
      start = ends[count][start];
      result.add(start);
    }
    return result;
  }

  double _height(List<Size> sizes, List<int> ends) {
    var start = 0;
    var height = 0.0;
    for (final end in ends) {
      if (start != 0) height += runSpacing;
      var rowHeight = 0.0;
      for (var i = start; i < end; i++) {
        rowHeight = math.max(rowHeight, sizes[i].height);
      }
      height += rowHeight;
      start = end;
    }
    return height;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    final sizes = [
      for (final child in _children) child.getDryLayout(childConstraints),
    ];
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : sizes.fold(0.0, (sum, child) => sum + child.width) +
              math.max(0, sizes.length - 1) * spacing;
    return constraints.constrain(
      Size(width, _height(sizes, _rowEnds(sizes, width))),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => _children.fold(
    0.0,
    (width, child) => math.max(width, child.getMinIntrinsicWidth(height)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = _children;
    return children.fold(
          0.0,
          (width, child) => width + child.getMaxIntrinsicWidth(height),
        ) +
        math.max(0, children.length - 1) * spacing;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  void performLayout() {
    final children = _children;
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    for (final child in children) {
      child.layout(childConstraints, parentUsesSize: true);
    }
    final sizes = [for (final child in children) child.size];
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : sizes.fold(0.0, (sum, child) => sum + child.width) +
              math.max(0, sizes.length - 1) * spacing;
    final ends = _rowEnds(sizes, width);
    size = constraints.constrain(Size(width, _height(sizes, ends)));

    var start = 0;
    var y = 0.0;
    for (final end in ends) {
      var x = 0.0;
      var rowHeight = 0.0;
      for (var i = start; i < end; i++) {
        final child = children[i];
        (child.parentData! as _BalancedWrapParentData).offset = Offset(
          textDirection == TextDirection.ltr
              ? x
              : size.width - x - child.size.width,
          y,
        );
        x += child.size.width + spacing;
        rowHeight = math.max(rowHeight, child.size.height);
      }
      y += rowHeight + runSpacing;
      start = end;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
