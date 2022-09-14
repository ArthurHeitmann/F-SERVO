
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/miscValues.dart';
import '../../stateManagement/openFilesManager.dart';

class HierarchyEntryWidget extends ChangeNotifierWidget {
  final HierarchyEntry entry;
  final int depth;

  HierarchyEntryWidget(this.entry, {this.depth = 0})
    : super(key: Key(entry.uuid), notifiers: [entry, shouldAutoTranslate]);

  @override
  State<HierarchyEntryWidget> createState() => _HierarchyEntryState();
}

class _HierarchyEntryState extends ChangeNotifierState<HierarchyEntryWidget> {
  bool isHovered = false;
  bool isClicked = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        setupContextMenu(
          child: optionallySetupSelectable(
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              height: 25,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 15.0 * widget.depth,),
                  if (widget.entry.isCollapsible)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, left: 2),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          maxWidth: 14
                        ),
                        splashRadius: 14,
                        onPressed: toggleCollapsed,
                        icon: Icon(widget.entry.isCollapsed ? Icons.chevron_right : Icons.expand_more, size: 17),
                      ),
                    ),
                  if (widget.entry.icon != null)
                    Icon(widget.entry.icon!, size: 15, color: widget.entry.iconColor,),
                  SizedBox(width: 5),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: widget.entry.name,
                      builder: (context, name, child) =>  Text(
                        widget.entry.name.toString(),
                        overflow: TextOverflow.ellipsis,
                        textScaleFactor: 0.85,
                      ),
                    )
                  )
                ]
              ),
            ),
          ),
        ),
        if (widget.entry.isCollapsible && !widget.entry.isCollapsed)
          for (var child in widget.entry)
            HierarchyEntryWidget(child, depth: widget.depth + 1,)
      ]
	  );
  }

  Widget setupContextMenu({ required Widget child }) {
    return ContextMenuRegion(
      enableLongPress: false,
      contextMenu: GenericContextMenu(
        buttonConfigs: [
          if (openHierarchyManager.contains(widget.entry))
            ContextMenuButtonConfig(
              "Close",
              onPressed: () => openHierarchyManager.remove(widget.entry),
            ),
        ],
      ),
      child: child,
    );
  }

  Widget optionallySetupSelectable(Widget child) {
    if (!widget.entry.isSelectable && !widget.entry.isCollapsible)
      return child;
    
    Color bgColor;
    if (widget.entry.isSelectable && widget.entry.isSelected)
      bgColor = getTheme(context).hierarchyEntrySelected!;
    else if (isClicked)
      bgColor = getTheme(context).hierarchyEntryClicked!;
    else if (isHovered)
      bgColor = getTheme(context).hierarchyEntryHovered!;
    else
      bgColor = Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) {
        isHovered = false;
        isClicked = false;
        setState(() {});
      },
      child: GestureDetector(
        onTap: onClick,
        onTapDown: (_) => setState(() => isClicked = true),
        onTapUp: (_) => setState(() => isClicked = false),
        child: AnimatedContainer(
          color: bgColor,
          duration: Duration(milliseconds: 75),
          child: child
        ),
      ),
    );
  }

  int lastClickAt = 0;

  bool isDoubleClick({ int intervalMs = 500 }) {
    int time = DateTime.now().millisecondsSinceEpoch;
    return time - lastClickAt < intervalMs;
  }

  void onClick() {
    if (widget.entry.isSelectable)
      openHierarchyManager.selectedEntry = widget.entry;
    if (widget.entry.isCollapsible && (!widget.entry.isSelectable || isDoubleClick()))
      toggleCollapsed();
    if (widget.entry.isOpenable && (!widget.entry.isSelectable || isDoubleClick()))
      onOpenFile();

    lastClickAt = DateTime.now().millisecondsSinceEpoch;
  }

  void onOpenFile() {
    areasManager.openFile((widget.entry as FileHierarchyEntry).path);
  }

  void toggleCollapsed() {
    widget.entry.isCollapsed = !widget.entry.isCollapsed;
  }
}
