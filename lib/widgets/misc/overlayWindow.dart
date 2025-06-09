
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../utils/utils.dart';
import '../theme/customTheme.dart';

class OverlayWindow extends StatefulWidget {
  final OverlayEntry overlayEntry;
  final Offset offset;
  final Size size;
  final String title;
  final Widget child;

  const OverlayWindow._({
    required this.overlayEntry,
    required this.offset,
    required this.size,
    required this.title,
    required this.child,
  });

  factory OverlayWindow.show({
    required BuildContext context,
    required Widget child,
    required String title,
    Offset? offset,
    Size? initSize,
    Size? initSizePercent,
    Size? initSizePercentLimit,
  }) {
    Size size;
    if (initSize != null) {
      size = initSize;
    } else if (initSizePercent != null) {
      var screenSize = MediaQuery.of(context).size;
      size = Size(
        min(initSizePercent.width * screenSize.width, initSizePercentLimit?.width ?? double.infinity),
        min(initSizePercent.height * screenSize.height, initSizePercentLimit?.height ?? double.infinity),
      );
    } else {
      size = Size(400, 400);
    }

    OverlayWindow? window;
    final overlayEntry = OverlayEntry(builder: (context) => window!);
    Overlay.of(context).insert(overlayEntry);
    if (offset == null) {
      final screenSize = MediaQuery.of(context).size;
      offset = Offset((screenSize.width - size.width) / 2, (screenSize.height - size.height) / 2);
    }
    window = OverlayWindow._(overlayEntry: overlayEntry, offset: offset, size: size, title: title, child: child);
    return window;
  }

  @override
  State<OverlayWindow> createState() => _OverlayWindowState();
}

class _OverlayWindowState extends State<OverlayWindow> {
  static const Size minSize = Size(250, 250);
  late Offset offset;
  late Size size;

  @override
  void initState() {
    super.initState();
    offset = widget.offset;
    size = widget.size;
  }

  void close() {
    widget.overlayEntry.remove();
  }

  void onWindowDrag(DragUpdateDetails details, Size screenSize) {
    offset = Offset(
      clamp(offset.dx + details.delta.dx, 0.0, screenSize.width - size.width),
      clamp(offset.dy + details.delta.dy, titleBarHeight, screenSize.height - size.height),
    );
    setState(() {});
  }

  void onLeftDrag(DragUpdateDetails details, Size screenSize) {
    var rightEdge = offset.dx + size.width - minSize.width;
    var left = clamp(offset.dx + details.delta.dx, 0.0, rightEdge);
    var leftDelta = left - offset.dx;
    offset = Offset(offset.dx + leftDelta, offset.dy);
    size = Size(size.width - leftDelta, size.height);
    setState(() {});
  }

  void onRightDrag(DragUpdateDetails details, Size screenSize) {
    var right = clamp(offset.dx + size.width + details.delta.dx, offset.dx + minSize.width, screenSize.width);
    var rightDelta = right - offset.dx - size.width;
    size = Size(size.width + rightDelta, size.height);
    setState(() {});
  }

  void onTopDrag(DragUpdateDetails details, Size screenSize) {
    var bottomEdge = offset.dy + size.height - minSize.height;
    var top = clamp(offset.dy + details.delta.dy, titleBarHeight, bottomEdge);
    var topDelta = top - offset.dy;
    offset = Offset(offset.dx, offset.dy + topDelta);
    size = Size(size.width, size.height - topDelta);
    setState(() {});
  }

  void onBottomDrag(DragUpdateDetails details, Size screenSize) {
    var bottom = clamp(offset.dy + size.height + details.delta.dy, offset.dy + minSize.height, screenSize.height);
    var bottomDelta = bottom - offset.dy - size.height;
    size = Size(size.width, size.height + bottomDelta);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    var left = clamp(offset.dx, 0.0, screenSize.width - size.width);
    var top = clamp(offset.dy, titleBarHeight, screenSize.height - size.height);
    var width = min(size.width, screenSize.width - left);
    var height = min(size.height, screenSize.height - top);
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: PointerInterceptor(
            child: Material(
              elevation: 8,
              color: getTheme(context).sidebarBackgroundColor,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: getTheme(context).dividerColor!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onPanUpdate: (details) => onWindowDrag(details, screenSize),
                      child: SizedBox(
                        height: 30,
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: close,
                              splashRadius: 16,
                              icon: const Icon(Icons.close, size: 18),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 1,
                      color: getTheme(context).dividerColor,
                    ),
                    Expanded(
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        makeSideDraggable(context, false, Offset(left, top), 0, width, onTopDrag),
        makeSideDraggable(context, false, Offset(left, top), height, width, onBottomDrag),
        makeSideDraggable(context, true, Offset(left, top), 0, height, onLeftDrag),
        makeSideDraggable(context, true, Offset(left, top), width, height, onRightDrag),
        makeCornerDraggable(context, SystemMouseCursors.resizeUpLeftDownRight, Offset(left, top), onTopDrag, onLeftDrag),
        makeCornerDraggable(context, SystemMouseCursors.resizeUpRightDownLeft, Offset(left + width - 6, top), onTopDrag, onRightDrag),
        makeCornerDraggable(context, SystemMouseCursors.resizeUpRightDownLeft, Offset(left, top + height - 6), onBottomDrag, onLeftDrag),
        makeCornerDraggable(context, SystemMouseCursors.resizeUpLeftDownRight, Offset(left + width - 6, top + height - 6), onBottomDrag, onRightDrag),
      ],
    );
  }

  Widget makeSideDraggable(BuildContext context, bool isVertical, Offset offset, double axisOffset, double size, void Function(DragUpdateDetails, Size) onDrag) {
    return Positioned(
      top: offset.dy + max(0, isVertical ? 0 : axisOffset - 4),
      left: offset.dx + max(0, isVertical ? axisOffset - 4 : 0),
      width: isVertical ? 4 : size,
      height: isVertical ? size : 4,
      child: MouseRegion(
        cursor: isVertical ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
        child: GestureDetector(
          onPanUpdate: (details) => onDrag(details, MediaQuery.of(context).size),
        ),
      ),
    );
  }

  Widget makeCornerDraggable(BuildContext context, MouseCursor cursor, Offset offset, void Function(DragUpdateDetails, Size) onVerticalDrag, void Function(DragUpdateDetails, Size) onHorizontalDrag) {
    return Positioned(
      top: offset.dy,
      left: offset.dx,
      width: 6,
      height: 6,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanUpdate: (details) {
            onVerticalDrag(details, MediaQuery.of(context).size);
            onHorizontalDrag(details, MediaQuery.of(context).size);
          },
        ),
      ),
    );
  }
}
