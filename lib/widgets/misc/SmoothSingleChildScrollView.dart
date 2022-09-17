// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../utils.dart';

class SmoothSingleChildScrollView extends StatefulWidget {
  final ScrollController controller;
  final Duration duration;
  final double stepSize;
  final Widget child;

  const SmoothSingleChildScrollView({
    super.key,
    required this.controller,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.stepSize = 100,
  });

  @override
  State<SmoothSingleChildScrollView> createState() => _SmoothSingleChildScrollViewState();
}

class _SmoothSingleChildScrollViewState extends State<SmoothSingleChildScrollView> {
  double targetOffset = 0;

  @override
  void initState() {
    if (widget.controller.hasClients)
      targetOffset = widget.controller.offset;
    widget.controller.addListener(onScrollChange);
    super.initState();
  }

  void onScrollChange() {
    if (widget.controller.position.activity is! IdleScrollActivity)
      return;
    targetOffset = widget.controller.offset;
  }

  void onScroll(PointerScrollEvent event) {
    targetOffset += widget.stepSize * event.scrollDelta.dy.sign;
    targetOffset = clamp(targetOffset, 0, widget.controller.position.maxScrollExtent);
    if (targetOffset == widget.controller.offset)
      return;
    widget.controller.animateTo(targetOffset, duration: widget.duration, curve: Curves.linear);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) => event is PointerScrollEvent ? onScroll(event) : null,
      child: SingleChildScrollView(
        controller: widget.controller,
        physics: const _SmoothScrollNoScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}

class _SmoothScrollNoScrollPhysics extends ScrollPhysics {
  const _SmoothScrollNoScrollPhysics({ super.parent });

  @override
  _SmoothScrollNoScrollPhysics applyTo(ScrollPhysics? ancestor) { // TODO check platform
    return _SmoothScrollNoScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => false;

  @override
  bool get allowImplicitScrolling => false;
}
