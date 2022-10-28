
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../utils.dart';

class _NestedContextMenuIW extends InheritedWidget {
  final List<ContextMenuButtonConfig> contextChildren;
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

  List<ContextMenuButtonConfig> getAllWidgets() {
    return [
      ...contextChildren,
      ...(!clearParent ? _NestedContextMenuIW.of(parentContext)?.getAllWidgets() ?? [] : [])
    ];
  }
}

class NestedContextMenu extends StatelessWidget {
  final Widget child;
  final List<ContextMenuButtonConfig> buttons;
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
          return ContextMenuRegion(
            enableLongPress: isMobile,
            contextMenu: GenericContextMenu(
              buttonConfigs: _NestedContextMenuIW.of(context)!.getAllWidgets(),
            ),
            child: child,
          );
        }
      ),
    );
  }
}
