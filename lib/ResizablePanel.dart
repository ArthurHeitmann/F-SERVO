import 'dart:math';

import 'package:flutter/material.dart';

class ResizablePanel extends StatefulWidget {
  final Widget child;
  final bool dragTop, dragRight, dragBottom, dragLeft;
  final double initWidth, initHeight;
  final double minWidth, minHeight;
  final double maxWidth, maxHeight;

  ResizablePanel({Key? key, required this.child,
                        this.dragTop = false, this.dragRight = false, this.dragBottom = false, this.dragLeft = false,
                        this.initWidth = 200, this.initHeight = 200,
                        this.minWidth = 50, this.minHeight = 50,
                        this.maxWidth = 1000, this.maxHeight = 1000}
                        )
    : super(key: key) {
      assert(dragTop || dragBottom || dragLeft || dragRight);
      assert(!(dragTop && dragBottom));
      assert(!(dragLeft && dragRight));
    }

  @override
  State<ResizablePanel> createState() => ResizablePanelState();
}

class ResizablePanelState extends State<ResizablePanel> {
  double width = 0, height = 0;

  @override
  void initState() {
    super.initState();

    width = widget.initWidth;
    height = widget.initHeight;
  }

  void onWidthDragUpdate(DragUpdateDetails details) {
    setState(() {
      if (widget.dragLeft)
        width -= details.delta.dx;
      else
        width += details.delta.dx;
      width = max(widget.minWidth, min(widget.maxWidth, width));
    });
  }

  void onHeightDragUpdate(DragUpdateDetails details) {
    setState(() {
      if (widget.dragTop)
        height -= details.delta.dy;
      else
        height += details.delta.dy;
      height = max(widget.minHeight, min(widget.maxHeight, height));
    });
  }

  @override
  Widget build(BuildContext context) {
    var innerChild = widget.child;
    if (widget.dragTop || widget.dragBottom) {
      var draggable = GestureDetector(
        onPanUpdate: onHeightDragUpdate,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 2),
            color: Color.fromRGBO(255, 255, 255, 0.1),
          )
        ),
      );
      List<Widget> colChildren;
      if (widget.dragTop) {
        colChildren = [
          draggable,
          Expanded(
            child: widget.child,
          ),
        ];
      } else {
        colChildren = [
          Expanded(
            child: widget.child,
          ),
          draggable,
        ];
      }
      innerChild = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: colChildren,
      );
    }
    if (widget.dragLeft || widget.dragRight) {
      var draggable = GestureDetector(
        onPanUpdate: onWidthDragUpdate,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 2),
            color: Color.fromRGBO(255, 255, 255, 0.1),
          )
        ),
      );
      List<Widget> rowChildren;
      if (widget.dragLeft) {
        rowChildren = [
          draggable,
          Expanded(
            child: innerChild,
          ),
        ];
      } else {
        rowChildren = [
          Expanded(
            child: innerChild,
          ),
          draggable,
        ];
      }
      innerChild = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rowChildren,
      );
    }
    var selfWidth = min(max(width, widget.minWidth), widget.maxWidth);
    var selfHeight = min(max(height, widget.minHeight), widget.maxHeight);

    return ConstrainedBox(
      constraints: widget.dragLeft || widget.dragRight ?
        BoxConstraints(
          minWidth: selfWidth,
          maxWidth: selfWidth,
        )
        : BoxConstraints(
          minHeight: selfHeight,
          maxHeight: selfHeight,
        ),
      child: innerChild,
    );
  }
}

