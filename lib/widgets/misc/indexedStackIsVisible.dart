
import 'package:flutter/widgets.dart';

class IndexedStackIsVisible extends InheritedWidget {
  final bool isVisible;

  const IndexedStackIsVisible({
    super.key,
    required this.isVisible,
    required super.child,
  });

  static bool? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<IndexedStackIsVisible>()?.isVisible;
  }

  @override
  bool updateShouldNotify(IndexedStackIsVisible oldWidget) {
    return oldWidget.isVisible != isVisible;
  }
}
