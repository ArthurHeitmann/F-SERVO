
import 'package:flutter/material.dart';

typedef MousePoseChangeCallback = void Function(Offset offset);

class MousePosition extends StatelessWidget {
  final Widget child;
  static Offset _mousePos = const Offset(0, 0);
  static final List<MousePoseChangeCallback> _dragListeners = [];
  static final List<VoidCallback> _dragEndListeners = [];

  const MousePosition({super.key, required this.child});

  static Offset get pos => _mousePos;

  static void addDragListener(MousePoseChangeCallback callback) {
    _dragListeners.add(callback);
  }

  static void addDragEndListener(VoidCallback callback) {
    _dragEndListeners.add(callback);
  }

  static void removeDragListener(MousePoseChangeCallback callback) {
    _dragListeners.remove(callback);
  }

  static void removeDragEndListener(VoidCallback callback) {
    _dragEndListeners.remove(callback);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (event) {
        _mousePos = event.position;
      },
      onPointerMove: (e) {
        _mousePos = e.position;
        for (var listener in _dragListeners.toList())
          listener(_mousePos);
      },
      onPointerUp: (e) {
        _mousePos = e.position;
        for (var listener in _dragEndListeners.toList())
          listener();
      },
      child: child,
    );
  }
}
