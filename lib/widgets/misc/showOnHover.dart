
import 'package:flutter/material.dart';

class ShowOnHover extends StatefulWidget {
  final Widget? child;
  final Widget Function(BuildContext, bool isHovered)? builder;

  const ShowOnHover({super.key, required this.child}) : builder = null;

  const ShowOnHover.builder({super.key, required this.builder})
    : child = null;

  @override
  State<ShowOnHover> createState() => _ShowOnHoverState();
}

class _ShowOnHoverState extends State<ShowOnHover> {
  bool isHovered = false;

  void onMouseEnter(_) {
    isHovered = true;
    setState(() {});
  }

  void onMouseExit(_) {
    isHovered = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: onMouseEnter,
      onExit: onMouseExit,
      child: AnimatedOpacity(
        opacity: isHovered ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: widget.builder == null
          ? widget.child!
          : widget.builder!(context, isHovered),
      ),
    );
  }
}
