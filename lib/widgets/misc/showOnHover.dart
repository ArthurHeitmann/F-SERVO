
import 'package:flutter/material.dart';

import 'onHoverBuilder.dart';

class ShowOnHover extends StatelessWidget {
  final Widget? child;
  final Widget Function(BuildContext, bool isHovered)? builder;

  const ShowOnHover({super.key, required this.child}) : builder = null;

  const ShowOnHover.builder({super.key, required this.builder})
    : child = null;

  @override
  Widget build(BuildContext context) {
    return OnHoverBuilder(
      builder: (cxt, isHovering) => AnimatedOpacity(
        opacity: isHovering ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: builder == null
          ? child!
          : builder!(context, isHovering),
      ),
    );
  }
}
