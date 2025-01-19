// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import 'mousePosition.dart';

typedef ExpandedBuilder = Widget Function(BuildContext context, bool isExpanded);

class ExpandOnHover extends StatefulWidget {
  final Widget? child;
  final ExpandedBuilder? builder;
  final double size;

  const ExpandOnHover({ super.key, this.child, this.builder, this.size = 45 });
  
  @override
  State<ExpandOnHover> createState() => _ExpandOnHoverState();

  ExpandedBuilder get childBuilder => builder ?? (_, __) => child!;
}

class _ExpandOnHoverState extends State<ExpandOnHover> {
  final ChangeNotifier dismissNotifier = ChangeNotifier();
  Timer? expandTimer;
  OverlayEntry? overlayEntry;
  BuildContext? childContext;
  Rectangle? childRect;

  @override
  void initState() {
    super.initState();
    MousePosition.addMoveListener(_onMouseMove);
  }

  @override
  void dispose() {
    MousePosition.removeMoveListener(_onMouseMove);
    expandTimer?.cancel();
    overlayEntry?.remove();
    super.dispose();
  }

  void _onMouseMove(Offset offset) {
    if (overlayEntry == null)
      return;
    if (childRect == null)
      return;
    if (childRect!.containsPoint(Point(offset.dx, offset.dy)))
      return;
    dismissNotifier.notifyListeners();
  }

  void _expand() {
    // add overlay with expanded child
    var overlayState = Overlay.of(context);
    var renderBox = childContext!.findRenderObject() as RenderBox;
    var offset = renderBox.localToGlobal(Offset.zero);
    var size = renderBox.size;
    childRect = Rectangle(offset.dx, offset.dy, size.width, size.height);
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy,
        width: size.width,
        height: size.height,
        child: _ExpandedChild(
          smallSize: widget.size,
          dismissNotifier: dismissNotifier,
          builder: widget.childBuilder,
          onDismiss: () {
            overlayEntry!.remove();
            overlayEntry = null;
          },
        ),
      ),
    );
    overlayState.insert(overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (overlayEntry!= null)
          return;
        if (expandTimer != null)
          expandTimer!.cancel();
        expandTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted)
            _expand();
        });
      },
      onExit: (_) => expandTimer?.cancel(),
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        child: Builder(
          builder: (context) {
            childContext = context;
            return widget.childBuilder(context, false);
          }
        ),
      ),
    );
  }
}


class _ExpandedChild extends StatefulWidget {
  final double smallSize;
  final ExpandedBuilder builder;
  final VoidCallback onDismiss;
  final ChangeNotifier dismissNotifier;

  const _ExpandedChild({ required this.smallSize, required this.builder, required this.onDismiss, required this.dismissNotifier });

  @override
  State<_ExpandedChild> createState() => _ExpandedChildState();
}

class _ExpandedChildState extends State<_ExpandedChild> {
  bool isExpanded = false;
  Timer? dismissTimer;
  Timer? fallbackDismissTimer;

  static const _expandSize = 200;
  static const _expandDuration = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    fallbackDismissTimer = Timer(const Duration(seconds: 15), dismiss);
    widget.dismissNotifier.addListener(dismiss);
    waitForNextFrame().then((_) {
      if (mounted)
        setState(() => isExpanded = true);
    });
  }

  @override
  void dispose() {
    dismiss();
    widget.dismissNotifier.removeListener(dismiss);
    super.dispose();
  }

  void dismiss() async {
    if (!mounted)
      return;
    if (!isExpanded)
      return;
    fallbackDismissTimer?.cancel();
    if (dismissTimer != null)
      return;
    dismissTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted)
        return;
      isExpanded = false;
      setState(() {});
      await waitForNextFrame();
      await Future.delayed(_expandDuration);
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isExpanded ? _expandSize / widget.smallSize : 1,
      duration: _expandDuration,
      child: Container(
        width: widget.smallSize,
        height: widget.smallSize,
        alignment: Alignment.center,
        child: widget.builder(context, isExpanded),
      )
    );
  }
}
