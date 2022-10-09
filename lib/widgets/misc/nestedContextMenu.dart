
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

class _NestedContextMenuIW extends InheritedWidget {
  final List<ContextMenuButtonConfig> contextChildren;
  final BuildContext parentContext;
  final bool ignoreParent;

  const _NestedContextMenuIW({required this.parentContext, required this.contextChildren, required this.ignoreParent, required super.child});

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
      ...(!ignoreParent ? _NestedContextMenuIW.of(parentContext)?.getAllWidgets() ?? [] : [])
    ];
  }
}

class NestedContextMenu extends StatelessWidget {
  final Widget child;
  final List<ContextMenuButtonConfig> contextChildren;
  final bool ignoreParent;

  const NestedContextMenu({super.key, required this.contextChildren, required this.child, this.ignoreParent = false});


  @override
  Widget build(BuildContext context) {
    return _NestedContextMenuIW(
      parentContext: context,
      contextChildren: contextChildren,
      ignoreParent: ignoreParent,
      child: Builder(
        builder: (context) {
          return ContextMenuRegion(
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

// class ContextMenuButtonConfig {
//   final String text;
//   final String? secondaryText;
//   final Icon? icon;
//   final void Function()? onPressed;

//   const ContextMenuButtonConfig({ required this.text, this.secondaryText, this.icon, required this.onPressed}) ;

//   @override
//   String toString() {
//     return "ContextMenuButtonConfig(text: $text, onPressed: $onPressed, secondaryText: $secondaryText, icon: $icon)";
//   }
// }

// class _ContextMenuButton extends StatelessWidget {
//   final ContextMenuButtonConfig buttonConfig;

//   const _ContextMenuButton({required this.buttonConfig});

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: buttonConfig.onPressed,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3),
//         child: Row(
//           children: [
//             if (buttonConfig.icon != null)
//               buttonConfig.icon!,
//             if (buttonConfig.icon != null)
//               const SizedBox(width: 4),
//             Expanded(
//               child: Text(buttonConfig.text)
//             ),
//             if (buttonConfig.secondaryText != null)
//               Text(buttonConfig.secondaryText!, style: const TextStyle(fontSize: 10)),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _ContextMenu extends StatelessWidget {
//   final List<ContextMenuButtonConfig> buttons;

//   const _ContextMenu({required this.buttons});

//   @override
//   Widget build(BuildContext context) {
//     return ConstrainedBox(
//       constraints: BoxConstraints(maxWidth: 600, minWidth: 150),
//       child: Material(
//         color: Theme.of(context).backgroundColor,
//         borderRadius: const BorderRadius.all(Radius.circular(8)),
//         clipBehavior: Clip.antiAlias,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: buttons.map(
//             (b) => _ContextMenuButton(
//               buttonConfig: b,
//             )
//           ).toList(),
//         ),
//       )
//     );
//   }
// }
