
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../utils/utils.dart';
import '../widgets/theme/customTheme.dart';

class ResizableWidget extends StatefulWidget {
  final List<Widget> children;
  late final List<double> percentages;
  final Axis axis;
  final double draggableThickness;
  final double lineThickness;
  final Color? lineColor;

  ResizableWidget({
    Key? key,
    required this.children,
    List<double>? percentages,
    required this.axis,
    this.draggableThickness = 5,
    this.lineThickness = 1.5,
    this.lineColor
  }) : super(key: key) {
    if (percentages == null)
      this.percentages = List.filled(children.length, 1 / children.length);
    else
      this.percentages = percentages;
    assert(children.length == this.percentages.length);
    assert(this.percentages.every((element) => element >= 0));
    assert(this.percentages.reduce((value, element) => value + element) == 1);
  }

  @override
  State<ResizableWidget> createState() => _ResizableWidgetState();
}

class _ResizableWidgetState extends State<ResizableWidget> {
  final List<double> percentages = [];
  final Map<int, List<double>> prevPercentages = {};

  @override
  void initState() {
    super.initState();
    percentages.addAll(widget.percentages);
  }

  void onDrag(int separator, DragUpdateDetails details) {
    var renderTarget = context.findRenderObject() as RenderBox;
    var size = renderTarget.size;
    var delta = widget.axis == Axis.horizontal ? details.delta.dx : details.delta.dy;
    var totalSize = widget.axis == Axis.horizontal ? size.width : size.height;
    var curSize = totalSize * percentages[separator];
    var nextSize = totalSize * percentages[separator + 1];
    var minSize = 150;
    var maxSize = curSize + nextSize - minSize;
    var newSize = clamp(curSize + delta, minSize, maxSize);
    var newPercent = newSize / totalSize;
    var deltaPercent = newPercent - percentages[separator];
    percentages[separator] += deltaPercent;
    percentages[separator + 1] -= deltaPercent;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _updatePercentageFromParent();

    return LayoutBuilder(
      builder: (context, constraints) {
        var total = widget.axis == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
        var childSizes = percentages.map((e) => e * total - widget.draggableThickness).toList();
        childSizes.last += widget.draggableThickness;
        List<Widget> children = [];
        for (var i = 0; i < widget.children.length; i++) {
          children.add(_makeSizedBox(childSizes[i], widget.children[i]));
          if (i < widget.children.length - 1)
            children.add(_makeDraggable(i));
        }
        return widget.axis == Axis.horizontal
          ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
          )
          : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
          );
      },
    );
  }

  Widget _makeSizedBox(double size, Widget child) {
    return widget.axis == Axis.horizontal
      ? ConstrainedBox(constraints: BoxConstraints(minWidth: size, maxWidth: size), child: child)
      : ConstrainedBox(constraints: BoxConstraints(minHeight: size, maxHeight: size), child: child);
  }

  Widget _makeDraggable(int separator) {
    double? draggableWidth = widget.axis == Axis.horizontal ? widget.draggableThickness : null;
    double? draggableHeight = widget.axis == Axis.horizontal ? null : widget.draggableThickness;
    double? lineWidth = widget.axis == Axis.horizontal ? widget.lineThickness : null;
    double? lineHeight = widget.axis == Axis.horizontal ? null : widget.lineThickness;
    return MouseRegion(
      cursor: widget.axis == Axis.horizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) => onDrag(separator, details),
        child: SizedBox(
          width: draggableWidth,
          height: draggableHeight,
          child: Center(
            child: Container(
              width: lineWidth,
              height: lineHeight,
              color: widget.lineColor ?? getTheme(context).dividerColor,
            ),
          ),
        )
      ),
    );
  }

  void _updatePercentageFromParent() {
    if (widget.percentages.length == percentages.length)
      return;
    prevPercentages[percentages.length] = percentages.toList();
    percentages.clear();
    if (prevPercentages.containsKey(widget.percentages.length))
      percentages.addAll(prevPercentages[widget.percentages.length]!);
    else
      percentages.addAll(widget.percentages);
  }
}
