
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../utils/utils.dart';



class SmoothScrollBuilder extends StatefulWidget {
  final ScrollController? controller;
  final Widget Function(BuildContext context, ScrollController controller, ScrollPhysics? physics) builder;
  final Duration animationDuration;
  final double? stepSize;
  final double stepMultiplier;
  final Curve animationCurve;
  final ScrollPhysics? mobilePhysics;

  const SmoothScrollBuilder({
    super.key,
    this.controller,
    required this.builder,
    this.animationDuration = const Duration(milliseconds: 200),
    this.stepSize,
    this.stepMultiplier = 1.0,
    this.mobilePhysics = const ClampingScrollPhysics(),
    this.animationCurve = Curves.easeOutCubic,
  });

  @override
  State<SmoothScrollBuilder> createState() => _SmoothScrollBuilderState();
}

class _SmoothScrollBuilderState extends State<SmoothScrollBuilder> {
  static bool hasDetectedPlatform = false;
  static final ValueNotifier<bool> useMobilePhysics = ValueNotifier(true);
  static const ScrollPhysics desktopPhysics = NeverScrollableScrollPhysics();
  late final ScrollPhysics? mobilePhysics;
  late final ScrollController controller;
  static bool hasTouch = false;
  double targetOffset = 0;
  bool isScrolling = false;
  Timer? isScrollingTimer;
  bool isTrackpadScrolling = false;
  Timer? isTrackpadScrollingTimer;

  void firstInit() {
    if (hasDetectedPlatform)
      return;
    hasDetectedPlatform = true;
    if (kIsWeb) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        var screenSize = MediaQuery.of(context).size;
        var isPortrait = screenSize.height > screenSize.width;
        useMobilePhysics.value = isPortrait || screenSize.width < 800;
      });
    }
    else if (isDesktop) {
      useMobilePhysics.value = false;
    }
  }

  @override
  void initState() {
    firstInit();
    mobilePhysics = widget.mobilePhysics;
    controller = widget.controller ?? ScrollController();
    if (controller.hasClients)
      targetOffset = controller.offset;
    controller.addListener(onScrollChange);
    super.initState();
  }

  @override
  void dispose() {
    controller.removeListener(onScrollChange);
    isScrollingTimer?.cancel();
    if (widget.controller == null)
      controller.dispose();
    super.dispose();
  }

  void onScrollChange() {
    if (isScrolling)
      return;
    targetOffset = controller.offset;
  }

  void onAnimatedScrollEnd() {
    isScrolling = false;
  }

  void onWheelScroll(PointerScrollEvent event) {
    if (handleTrackpadScroll(event))
      return;
    useMobilePhysics.value = false;
    targetOffset += widget.stepSize != null
      ? widget.stepSize! * event.scrollDelta.dy.sign * widget.stepMultiplier
      : event.scrollDelta.dy * widget.stepMultiplier;
    targetOffset = _clamp(targetOffset, 0, controller.position.maxScrollExtent);
    if (targetOffset == controller.offset)
      return;
    isScrolling = true;
    controller.animateTo(targetOffset, duration: widget.animationDuration, curve: widget.animationCurve);
    isScrollingTimer?.cancel();
    isScrollingTimer = Timer(widget.animationDuration, onAnimatedScrollEnd);
  }

  bool handleTrackpadScroll(PointerScrollEvent event) {
    if (isTrackpadScrolling) {
      onTrackpadScroll();
      return true;
    }
    if (event.scrollDelta.dy.abs() > 10)
      return false;
    isTrackpadScrolling = true;
    useMobilePhysics.value = true;
    onTrackpadScroll();
    return true;
  }

  void onTrackpadScroll() {
    isTrackpadScrolling = true;
    isTrackpadScrollingTimer?.cancel();
    isTrackpadScrollingTimer = Timer(const Duration(milliseconds: 250), () {
      isTrackpadScrolling = false;
      isTrackpadScrollingTimer = null;
    });
  }

  void checkHasTouch(PointerEvent event) {
    if (event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.trackpad)
      hasTouch = true;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        // print("${event.runtimeType} ${event.kind} ${event is PointerScrollEvent ? event.scrollDelta.dy : ""}}}");
        checkHasTouch(event);
        if (event is PointerScrollEvent)
          onWheelScroll(event);
      },
      onPointerDown: (event) {
        // print("${event.runtimeType} ${event.kind}");
        checkHasTouch(event);
        useMobilePhysics.value = true;
      },
      onPointerUp: (event) {
        // print("${event.runtimeType} ${event.kind}");
        checkHasTouch(event);
        if (!hasTouch)
          useMobilePhysics.value = false;
      },
      onPointerPanZoomStart: (event) {
        // print("${event.runtimeType} ${event.kind}");
        checkHasTouch(event);
        useMobilePhysics.value = true;
      },
      child: ListenableBuilder(
        listenable: useMobilePhysics,
        builder: (context, _) {
          return widget.builder(context, controller, useMobilePhysics.value ? mobilePhysics : desktopPhysics);
        }
      ),
    );
  }
}

class SmoothSingleChildScrollView extends StatelessWidget {
  final ScrollController? controller;
  final Duration animationDuration;
  final double? stepSize;
  final double stepMultiplier;
  final Curve animationCurve;
  final ScrollPhysics? mobilePhysics;
  final Axis scrollDirection;
  final Widget child;

  const SmoothSingleChildScrollView({
    super.key,
    this.controller,
    this.animationDuration = const Duration(milliseconds: 200),
    this.stepSize,
    this.stepMultiplier = 1.0,
    this.animationCurve = Curves.easeOutCubic,
    this.mobilePhysics = const ClampingScrollPhysics(),
    this.scrollDirection = Axis.vertical,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SmoothScrollBuilder(
      controller: controller,
      animationDuration: animationDuration,
      stepSize: stepSize,
      stepMultiplier: stepMultiplier,
      animationCurve: animationCurve,
      mobilePhysics: mobilePhysics,
      builder: (context, controller, physics) => SingleChildScrollView(
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        child: child,
      ),
    );
  }
}

T _clamp<T extends num>(T value, T min, T max) {
  assert(min <= max);
  if (value < min)
    return min;
  if (value > max)
    return max;
  return value;
}
