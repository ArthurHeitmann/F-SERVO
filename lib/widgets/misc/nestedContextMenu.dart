
import 'package:flutter/material.dart';

import 'contextMenuBuilder.dart';

class _NestedContextMenuIW extends InheritedWidget {
  final List<ContextMenuConfig?> contextChildren;
  final BuildContext parentContext;
  final bool clearParent;

  const _NestedContextMenuIW({required this.parentContext, required this.contextChildren, required this.clearParent, required super.child});

  static _NestedContextMenuIW? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_NestedContextMenuIW>();
  }
  
  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true;
  }

  List<ContextMenuConfig?> getAllConfigs() {
    return [
      ...contextChildren,
      ...(!clearParent ? _NestedContextMenuIW.of(parentContext)?.getAllConfigs() ?? [] : [])
    ];
  }
}

class NestedContextMenu extends StatelessWidget {
  final Widget child;
  final List<ContextMenuConfig?> buttons;
  final bool clearParent;

  const NestedContextMenu({super.key, required this.buttons, required this.child, this.clearParent = false});


  @override
  Widget build(BuildContext context) {
    return _NestedContextMenuIW(
      parentContext: context,
      contextChildren: buttons,
      clearParent: clearParent,
      child: Builder(
        builder: (context) {
          var config = _NestedContextMenuIW.of(context)!.getAllConfigs();
          // remove leading & trailing nulls
          while (config.isNotEmpty && config.first == null)
            config.removeAt(0);
          while (config.isNotEmpty && config.last == null)
            config.removeLast();
          // remove neighboring nulls
          for (int i = 0; i < config.length - 1; i++) {
            if (config[i] == null && config[i + 1] == null) {
              config.removeAt(i);
              i--;
            }
          }
          return ContextMenu(
            config: config,
            child: child,
          );
        }
      ),
    );
  }
}
