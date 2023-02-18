
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../utils/utils.dart';


class SmoothScrollBuilder extends StatefulWidget {
  final ScrollController controller;
  final Duration duration;
  final double stepSize;
  final ScrollPhysics? physics;
  final Widget Function(BuildContext context, ScrollController controller, ScrollPhysics? physics) builder;

  const SmoothScrollBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.duration = const Duration(milliseconds: 150),
    this.stepSize = 100,
    this.physics,
  });

  @override
  State<SmoothScrollBuilder> createState() => _SmoothScrollBuilderState();
}

class _SmoothScrollBuilderState extends State<SmoothScrollBuilder> {
  static const ScrollPhysics desktopPhysics = NeverScrollableScrollPhysics();
  static const ScrollPhysics mobilePhysics = BouncingScrollPhysics();
  double targetOffset = 0;
  bool isScrolling = false;
  Timer? isScrollingTimer;
  ScrollPhysics? physics = desktopPhysics;

  @override
  void initState() {
    if (widget.controller.hasClients)
      targetOffset = widget.controller.offset;
    widget.controller.addListener(onScrollChange);
    super.initState();
  }

  void onScrollChange() {
    if (isScrolling)
      return;
    targetOffset = widget.controller.offset;
  }

  void onScrollEnd() {
    isScrolling = false;
  }

  void onWheelScroll(PointerScrollEvent event) {
    if (physics != desktopPhysics)
      setState(() => physics = desktopPhysics);
    targetOffset += widget.stepSize * event.scrollDelta.dy.sign;
    targetOffset = clamp(targetOffset, 0, widget.controller.position.maxScrollExtent);
    if (targetOffset == widget.controller.offset)
      return;
    isScrolling = true;
    widget.controller.animateTo(targetOffset, duration: widget.duration, curve: Curves.linear);
    isScrollingTimer?.cancel();
    isScrollingTimer = Timer(widget.duration, onScrollEnd);
  }

  void onContinuosScroll() {
    if (physics != mobilePhysics)
      setState(() => physics = mobilePhysics);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) => event is PointerScrollEvent ? onWheelScroll(event) : null,
      onPointerDown: (_) => onContinuosScroll(),
      child: widget.builder(context, widget.controller, physics),
    );
  }
}

class SmoothSingleChildScrollView extends StatelessWidget {
  final ScrollController controller;
  final Duration duration;
  final double stepSize;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final Widget child;

  const SmoothSingleChildScrollView({
    super.key,
    required this.controller,
    this.duration = const Duration(milliseconds: 150),
    this.stepSize = 100,
    this.physics,
    this.scrollDirection = Axis.vertical,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SmoothScrollBuilder(
      controller: controller,
      duration: duration,
      stepSize: stepSize,
      physics: physics,
      builder: (context, controller, physics) => SingleChildScrollView(
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        child: child,
      ),
    );
  }
}
