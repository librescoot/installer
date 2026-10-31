import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Enlarges the preview only when the existing list layout has room for it.
class RequirementsPreviewRow extends MultiChildRenderObjectWidget {
  RequirementsPreviewRow({
    super.key,
    required Widget list,
    required Widget preview,
  }) : super(children: [list, preview]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRequirementsPreviewRow();
}

class _PreviewParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderRequirementsPreviewRow extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  static const _gap = 16.0;
  static const _originalPreviewWidth = 132.0;
  static const _originalPreviewHeight = 66.0;
  static const _aspectRatio = 16 / 9;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _PreviewParentData();
    }
  }

  double _rowHeight(double width) => math.max(
    _originalPreviewHeight,
    firstChild!.getMaxIntrinsicHeight(width - _gap - _originalPreviewWidth),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    Size(constraints.maxWidth, _rowHeight(constraints.maxWidth)),
  );

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final height = _rowHeight(width);
    final list = firstChild!;
    final preview = lastChild!;
    var low = 0.0;
    var high = math.min(280.0, height * _aspectRatio);
    // Keep the original row height, including its text wrapping. A larger
    // thumbnail must not push the firmware controls down by even one line.
    while (high - low > 0.25) {
      final candidate = (low + high) / 2;
      if (list.getMaxIntrinsicHeight(width - _gap - candidate) <= height) {
        low = candidate;
      } else {
        high = candidate;
      }
    }
    list.layout(
      BoxConstraints.tightFor(width: width - _gap - low),
      parentUsesSize: true,
    );
    preview.layout(
      BoxConstraints.tightFor(width: low, height: low / _aspectRatio),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(width, height));
    (list.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
      0,
      (size.height - list.size.height) / 2,
    );
    (preview.parentData! as ContainerBoxParentData<RenderBox>).offset = Offset(
      width - preview.size.width,
      (size.height - preview.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
