
import 'package:flutter/material.dart';

class OnHoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovering) builder;
  final MouseCursor cursor;

  const OnHoverBuilder({ super.key, required this.builder, this.cursor = MouseCursor.defer });

  @override
  State<OnHoverBuilder> createState() => _OnHoverBuilderState();
}

class _OnHoverBuilderState extends State<OnHoverBuilder> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      cursor: widget.cursor,
      child: widget.builder(context, isHovering),
    );
  }
}
