

import 'package:flutter/material.dart';

class ReorderableDraggableList extends StatefulWidget {
  final List<Widget> children;
  final Axis axis;
  final void Function()? onDragStart;
  final void Function()? onDragEnd;

  const ReorderableDraggableList({super.key, required this.axis, this.onDragStart, this.onDragEnd, required this.children});

  @override
  State<ReorderableDraggableList> createState() => _ReorderableDraggableListState();
}

class _ReorderableDraggableListState extends State<ReorderableDraggableList> {
  Widget? draggedChild;
  int beforeDragChildIndex = -1;
  int currentDragChildIndex = -1;
  Size draggedSize = Size.zero;
  double draggedOffset = 0;

  bool get isDragging => draggedChild != null;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _makeContainer(
            children: [
              for (var child in widget.children)
                child == draggedChild
                  ? SizedBox(width: draggedSize.width, height: draggedSize.height,)
                  : child
            ],
          ),
        ),
        if (isDragging)
          Positioned(
            top: widget.axis == Axis.horizontal ? 0 : draggedOffset,
            left: widget.axis == Axis.horizontal ? draggedOffset : 0,
            child: draggedChild!
          )
      ],
    );
  }

  Widget _makeContainer({ required List<Widget> children }) => widget.axis == Axis.horizontal
    ? Row(mainAxisSize: MainAxisSize.min,children: children,)
    : Column(mainAxisSize: MainAxisSize.min, children: children,); 
}
