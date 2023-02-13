
import 'package:dyn_mouse_scroll/dyn_mouse_scroll.dart';
import 'package:flutter/material.dart';


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

  @override
  Widget build(BuildContext context) {
    return DynMouseScroll(
      durationMS: widget.duration.inMilliseconds,
      mobilePhysics: widget.physics ?? const BouncingScrollPhysics(),
      builder: (context, controller, physics) => widget.builder(
        context,
        controller,
        physics,
      )
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

