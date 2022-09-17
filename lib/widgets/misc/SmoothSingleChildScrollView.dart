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
  bool overrideScrollBehavior = true;

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

  void onWheelScroll(PointerScrollEvent event) {
    if (!overrideScrollBehavior)
      setState(() => overrideScrollBehavior = true);
    targetOffset += widget.stepSize * event.scrollDelta.dy.sign;
    targetOffset = clamp(targetOffset, 0, widget.controller.position.maxScrollExtent);
    if (targetOffset == widget.controller.offset)
      return;
    widget.controller.animateTo(targetOffset, duration: widget.duration, curve: Curves.linear);
  }

  void onContinuosScroll(double dy) {
    if (overrideScrollBehavior)
      setState(() => overrideScrollBehavior = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (event) => onContinuosScroll(event.delta.dy),
      child: Listener(
        onPointerSignal: (event) => event is PointerScrollEvent ? onWheelScroll(event) : null,
        child: SingleChildScrollView(
          controller: widget.controller,
          physics: overrideScrollBehavior ? NeverScrollableScrollPhysics() : null,
          child: widget.child,
        ),
      ),
    );
  }
}
