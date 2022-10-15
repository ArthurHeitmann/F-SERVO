
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';


typedef OnWidgetSizeChange = void Function(Size size);

class _WidgetSizeRenderObject extends RenderProxyBox {
  final OnWidgetSizeChange onSizeChange;
  Size? currentSize;

  _WidgetSizeRenderObject(this.onSizeChange);

  @override
  void performLayout() {
    super.performLayout();

    Size? newSize = child?.size;

    if (newSize != null && currentSize != newSize) {
      currentSize = newSize;
      onSizeChange(newSize);
    }
  }
}

class WidgetSizeWrapper extends SingleChildRenderObjectWidget {
  final OnWidgetSizeChange onSizeChange;

  const WidgetSizeWrapper({
    Key? key,
    required this.onSizeChange,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _WidgetSizeRenderObject(onSizeChange);
  }
}
