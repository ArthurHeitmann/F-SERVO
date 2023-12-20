
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../stateManagement/preferencesData.dart';
import '../theme/customTheme.dart';
import '../theme/nierTheme.dart';
import 'mousePosition.dart';

class ContextMenuConfig {
  final String label;
  final Icon? icon;
  final String? shortcutLabel;
  final void Function()? action;

  const ContextMenuConfig({required this.label, this.icon, this.shortcutLabel, this.action});
}

class ContextMenu extends StatefulWidget {
  final List<ContextMenuConfig?> config;
  final Widget child;

  const ContextMenu({super.key, required this.config, required this.child});

  @override
  State<ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
  OverlayEntry? _overlayEntry;
  static List<_ContextMenuState> openMenus = [];

  @override
  void dispose() {
    if (_overlayEntry != null)
      hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: () => showContextMenu(),
      onLongPressDown: (details) => details.kind == PointerDeviceKind.touch ? showContextMenu() : null,
      child: widget.child,
    );
  }

  void showContextMenu() {
    for (var menu in openMenus.toList())
      menu.hide();
    hide();
    var pos = MousePosition.pos;
    _overlayEntry = OverlayEntry(
      builder: (context) {
        var size = MediaQuery.of(context).size;
        var x = min(pos.dx, size.width - 300);
        var y = min(pos.dy, size.height - 300);
        return _ContextMenu(
          config: widget.config,
          x: x,
          y: y,
          hide: hide,
        );
      }
    );
    Overlay.of(context).insert(_overlayEntry!);
    openMenus.add(this);
  }

  void hide() {
    if (_overlayEntry == null)
      return;
    _overlayEntry?.remove();
    openMenus.remove(this);
    _overlayEntry = null;
  }
}

class _ContextMenu extends StatelessWidget {
  final List<ContextMenuConfig?> config;
  final double x;
  final double y;
  final VoidCallback hide;

  const _ContextMenu({required this.config, required this.x, required this.y, required this.hide});

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    for (var config in config) {
      if (config == null) {
        children.add(buildSeparator(context));
      } else {
        children.add(buildMenuItem(context, config, hide));
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => hide(),
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Positioned(
          left: x,
          top: y,
          child: Theme(
            data: PreferencesData().makeTheme(context),
            child: Builder(
              builder: (context) {
                return CustomPaint(
                  foregroundPainter: Theme.of(context).brightness == Brightness.light ? const NierOverlayPainter(vignette: false) : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300, minWidth: 200),
                    child: Material(
                      color: getTheme(context).contextMenuBgColor,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      clipBehavior: Clip.antiAlias,
                      elevation: 5,
                      shadowColor: Colors.black,
                      child: IntrinsicWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: children,
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMenuItem(BuildContext context, ContextMenuConfig config, VoidCallback hide) {
    return InkWell(
      onTap: () {
        config.action?.call();
        hide();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5),
        child: Row(
          children: [
            if (config.icon != null)
              config.icon!,
            if (config.icon != null)
              const SizedBox(width: 8),
            if (config.icon == null)
              const SizedBox(width: 16),
            Expanded(
                child: Text(config.label, overflow: TextOverflow.ellipsis,)
            ),
            if (config.shortcutLabel != null) ...[
              const SizedBox(width: 8),
              Text(
                config.shortcutLabel!,
                style: TextStyle(
                  color: getTheme(context).textColor!.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget buildSeparator(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
    );
  }
}

