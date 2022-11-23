
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../utils/utils.dart';

class _NestedContextMenuIW extends InheritedWidget {
  final List<ContextMenuButtonConfig?> contextChildren;
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

  List<ContextMenuButtonConfig?> getAllWidgets() {
    return [
      ...contextChildren,
      ...(!clearParent ? _NestedContextMenuIW.of(parentContext)?.getAllWidgets() ?? [] : [])
    ];
  }
}

class NestedContextMenu extends StatelessWidget {
  final Widget child;
  final List<ContextMenuButtonConfig?> buttons;
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
          var buttons = _NestedContextMenuIW.of(context)!.getAllWidgets();
          // remove leading & trailing nulls
          while (buttons.isNotEmpty && buttons.first == null)
            buttons.removeAt(0);
          while (buttons.isNotEmpty && buttons.last == null)
            buttons.removeLast();
          // remove neighboring nulls
          for (int i = 0; i < buttons.length - 1; i++) {
            if (buttons[i] == null && buttons[i + 1] == null) {
              buttons.removeAt(i);
              i--;
            }
          }
          return ContextMenuRegion(
            enableLongPress: isMobile,
            contextMenu: GenericContextMenu(
              buttonConfigs: buttons,
            ),
            child: child,
          );
        }
      ),
    );
  }
}
