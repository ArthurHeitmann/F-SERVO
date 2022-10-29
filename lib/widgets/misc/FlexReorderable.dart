
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../utils/utils.dart';
import 'WidgetSizeWrapper.dart';
import 'mousePosition.dart';

class _FlexDraggableIW extends InheritedWidget {
  final void Function() onDragStart;

  const _FlexDraggableIW({
    required super.child,
    required this.onDragStart,
  });
  
  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return onDragStart != (oldWidget as _FlexDraggableIW).onDragStart;
  }

  static _FlexDraggableIW? of(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_FlexDraggableIW>();
}

class FlexDraggableHandle extends StatelessWidget {
  final Widget child;
  const FlexDraggableHandle({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    _FlexDraggableIW notifier = _FlexDraggableIW.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (e) {
        notifier.onDragStart();
      },
      child: child,
    );
  }
}

class FlexReorderable extends StatefulWidget {
  final Axis direction;
  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final void Function(int oldIndex, int newIndex) onReorder;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;

  FlexReorderable({
    super.key,
    required this.direction,
    required this.children,
    this.header,
    this.footer,
    required this.onReorder,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    assert(children.every((c) => c.key != null));
  }

  @override
  State<FlexReorderable> createState() => _FlexReorderableState();
}

class ColumnReorderable extends FlexReorderable {
  ColumnReorderable({
    super.key,
    required super.children,
    super.header,
    super.footer,
    required super.onReorder,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
  }) : super(direction: Axis.vertical);
}

class RowReorderable extends FlexReorderable {
  RowReorderable({
    super.key,
    required super.children,
    super.header,
    super.footer,
    required super.onReorder,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
  }) : super(direction: Axis.horizontal);
}

class _FlexReorderableState extends State<FlexReorderable> {
  static const int animDuration = 250;
  final List<Size> _childrenSizes = [];
  List<Key> comparisonKeys = [];
  // during dragging:
  Widget? draggedWidget;
  int draggedIndex = -1;
  int newDraggedIndex = -1;
  double draggedOffset = 0.0;
  double offsetOffset = 0;
  BoxConstraints draggedConstraints = const BoxConstraints();
  double get draggedExtent => getSizeExtent(draggedConstraints.biggest);
  bool isListeningToDragUpdates = false;
  // drag end:
  bool isPlayingDragEndAnimation = false;
  bool disableAnimations = false;

  @override
  void initState() {
    comparisonKeys = List<Key>.generate(widget.children.length, (i) => makeReferenceKey(widget.children[i].key!));
    super.initState();
  }

  @override
  void dispose() {
    clearListeners();
    
    super.dispose();
  }

  double getSizeExtent(Size s) =>
    widget.direction == Axis.vertical ? s.height : s.width;

  double getOffsetExtent(Offset o) =>
    widget.direction == Axis.vertical ? o.dy : o.dx;

  void clearListeners() {
    if (!isListeningToDragUpdates)
      return;
    MousePosition.removeDragListener(onDragUpdate);
    MousePosition.removeDragEndListener(onDragEnd);
    isListeningToDragUpdates = false;
  }

  void checkForKeyChanges() {
    bool didKeyChange = widget.children.length != comparisonKeys.length;
    for (int i = 0; i < widget.children.length && !didKeyChange; i++) {
      if (makeReferenceKey(widget.children[i].key!) != comparisonKeys[i]) {
        didKeyChange = true;
        break;
      }
    }
    if (!didKeyChange)
      return;
    
    List<Size> newSizes = List.filled(widget.children.length, Size.zero);
    for (var i = 0; i < widget.children.length; i++) {
      var oldPos = comparisonKeys.indexOf(makeReferenceKey(widget.children[i].key!));
      if (oldPos != -1)
        newSizes[i] = _childrenSizes[oldPos];
    }
    _childrenSizes.clear();
    _childrenSizes.addAll(newSizes);
    comparisonKeys = List<Key>.generate(widget.children.length, (i) => makeReferenceKey(widget.children[i].key!));
  }

  List<Size> getChildrenSizes() {
    if (draggedIndex == -1 || newDraggedIndex == -1)
      return _childrenSizes;
    var sizes = _childrenSizes.toList();
    var old = sizes.removeAt(draggedIndex);
    sizes.insert(newDraggedIndex, old);
    return sizes;
  }

  void onChildSizeChange(Size size, int i) {
    if (_childrenSizes.length <= i)
      _childrenSizes.addAll(Iterable.generate(i - _childrenSizes.length + 1, (_) => Size.zero));
    
    _childrenSizes[i] = size;
  }

  double getIntersectionRatio(double aMin, double aMax, double bMin, double bMax) {
    final iMin = max(aMin, bMin);
    final iMax = min(aMax, bMax);
    if (iMin > iMax)
      return 0;
    return min((iMax - iMin) / (aMax - aMin), 1);
  }

  int getChildIndexStatic() {
    assert(widget.children.length == _childrenSizes.length);

    var childSizes = getChildrenSizes();
    double curOffset = 0;
    for (var i = 0; i < widget.children.length; i++) {
      double childMin = curOffset;
      double childMax = curOffset + getSizeExtent(childSizes[i]);
      if (between(draggedOffset, childMin, childMax))
        return i;
      curOffset += getSizeExtent(childSizes[i]);
    }

    return 0;
  }

  int getChildIndexDrag() {
    assert(widget.children.length == _childrenSizes.length);

    var childSizes = getChildrenSizes();
    double draggedMin = draggedOffset;
    double draggedMax = draggedOffset + draggedExtent;
    double curOffset = 0;
    int maxIndex = draggedIndex;
    double maxRatio = 0;
    for (var i = 0; i < widget.children.length; i++) {
      double childMin = curOffset;
      double childMax = curOffset + getSizeExtent(childSizes[i]);
      double ratio = getIntersectionRatio(childMin, childMax, draggedMin, draggedMax);
      if (ratio > maxRatio) {
        maxRatio = ratio;
        maxIndex = i;
      }
      curOffset += getSizeExtent(childSizes[i]);
    }

    return maxIndex;
  }

  double getChildStartOffset(int i) {
    var childSizes = getChildrenSizes();
    double offset = 0;
    for (int j = 0; j < i; j++) 
      offset += getSizeExtent(childSizes[j]);
      
    return offset;
  }

  void onDragStart() {
    var ownRenderBox = context.findRenderObject() as RenderBox;
    draggedOffset = getOffsetExtent(ownRenderBox.globalToLocal(MousePosition.pos));
    int i = getChildIndexStatic();
    
    draggedIndex = i;
    newDraggedIndex = i;
    draggedWidget = widget.children[i];
    draggedConstraints = BoxConstraints.tight(_childrenSizes[i]);
    offsetOffset = draggedOffset - getChildStartOffset(i);
    draggedOffset -= offsetOffset;
    draggedOffset = clamp(draggedOffset, 0, getSizeExtent(ownRenderBox.size) - draggedExtent);

    clearListeners();
    MousePosition.addDragListener(onDragUpdate);
    MousePosition.addDragEndListener(onDragEnd);
    isListeningToDragUpdates = true;

    setState(() {});
  }

  void onDragUpdate(Offset pos) {
    var ownRenderBox = context.findRenderObject() as RenderBox;
    draggedOffset = getOffsetExtent(ownRenderBox.globalToLocal(pos)) - offsetOffset;
    draggedOffset = clamp(draggedOffset, 0, getSizeExtent(ownRenderBox.size) - draggedExtent);
    newDraggedIndex = getChildIndexDrag();

    setState(() {});
  }

  void onDragEnd() async {
    clearListeners();

    draggedOffset = getChildStartOffset(newDraggedIndex);
    isPlayingDragEndAnimation = true;
    setState(() {});

    await Future.delayed(const Duration(milliseconds: animDuration));

    widget.onReorder(draggedIndex, newDraggedIndex);
    var prevSize = _childrenSizes.removeAt(draggedIndex);
    _childrenSizes.insert(newDraggedIndex, prevSize);
    var prevKey = comparisonKeys.removeAt(draggedIndex);
    comparisonKeys.insert(newDraggedIndex, prevKey);
    draggedIndex = -1;
    newDraggedIndex = -1;
    draggedWidget = null;
    isPlayingDragEndAnimation = false;
    
    disableAnimations = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      disableAnimations = false;
    });

    setState(() {});
  }

  double getChildOffset(int i) {
    if (draggedIndex == -1)
      return 0;
    if (draggedIndex == i)
      return draggedOffset;
    if (between(i, newDraggedIndex, draggedIndex))
      return draggedExtent;
    if (between(i, draggedIndex, newDraggedIndex))
      return -draggedExtent;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    checkForKeyChanges();
    return _FlexDraggableIW(
      onDragStart: onDragStart,
      child: headerFooterWrapper(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Flex(
              direction: widget.direction,
              mainAxisAlignment: widget.mainAxisAlignment,
              mainAxisSize: widget.mainAxisSize,
              crossAxisAlignment: widget.crossAxisAlignment,
              children: [
                for (int i = 0; i < widget.children.length; i++)
                  if (i == draggedIndex)
                    ConstrainedBox(constraints: draggedConstraints)
                  else
                    _FlexReorderableChildWrapper(
                      key: makeReferenceKey(widget.children[i].key!),
                      animate: !disableAnimations,
                      transform: widget.direction == Axis.vertical
                        ? Matrix4.translationValues(0, getChildOffset(i), 0)
                        : Matrix4.translationValues(getChildOffset(i), 0, 0),
                      onSizeChange: (size) => onChildSizeChange(size, i),
                      child: widget.children[i],
                    ),
              ],
            ),
            if (draggedWidget != null)
              AnimatedPositioned(
                duration: Duration(milliseconds: isPlayingDragEndAnimation ? animDuration : 0),
                top: widget.direction == Axis.vertical ? draggedOffset : null,
                left: widget.direction == Axis.horizontal ? draggedOffset : null,
                child: ConstrainedBox(
                  constraints: draggedConstraints,
                  child: draggedWidget,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget headerFooterWrapper({ required Widget child }) {
    if (widget.header == null && widget.footer == null)
      return child;
    return Flex(
      direction: widget.direction,
      mainAxisSize: widget.mainAxisSize,
      mainAxisAlignment: widget.mainAxisAlignment,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        if (widget.header != null)
          widget.header!,
        child,
        if (widget.footer != null)
          widget.footer!,
      ],
    );
  }
}

class _FlexReorderableChildWrapper extends StatelessWidget {
  final Widget child;
  final bool animate;
  final Matrix4 transform;
  final OnWidgetSizeChange onSizeChange;

  const _FlexReorderableChildWrapper({super.key, required this.child, required this.transform, required this.onSizeChange, required this.animate });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: animate ? _FlexReorderableState.animDuration : 0),
      transform: transform,
      child: WidgetSizeWrapper(
        onSizeChange: onSizeChange,
        child: child,
      ),
    );
  }
}
