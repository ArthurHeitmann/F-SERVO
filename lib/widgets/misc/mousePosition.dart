
import 'package:flutter/material.dart';


class MousePosition extends StatelessWidget {
  final Widget child;
  static Offset _mousePos = Offset(0, 0);

  const MousePosition({super.key, required this.child});

  static Offset get pos => _mousePos;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        _mousePos = event.position;
      },
      child: child,
    );
  }
}
