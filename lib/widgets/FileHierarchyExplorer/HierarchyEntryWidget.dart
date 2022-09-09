
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/nestedNotifier.dart';

class HierarchyEntryWidget extends ChangeNotifierWidget {
  final HierarchyEntry entry;
  final int depth;

  const HierarchyEntryWidget(this.entry, {super.key, this.depth = 0}) : super(notifier: entry);

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
        optionallySetupSelectable(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3),
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 15.0 * widget.depth,),
                if (widget.entry.isCollapsible)
                  Padding(
                    padding: const EdgeInsets.only(right: 4, left: 2),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      splashRadius: 13,
                      onPressed: toggleCollapsed,
                      icon: Icon(widget.entry.isCollapsed ? Icons.chevron_right : Icons.expand_more, size: 17),
                    ),
                  ),
                if (widget.entry.icon != null)
                  Icon(widget.entry.icon!, size: 15),
                SizedBox(width: 5),
                Expanded(
                  child: Text(widget.entry.name, overflow: TextOverflow.ellipsis,)
                )
              ]
            ),
          ),
        ),
        if (widget.entry.isCollapsible && !widget.entry.isCollapsed)
          for (var child in widget.entry)
            HierarchyEntryWidget(child, depth: widget.depth + 1,)
      ]
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

  void onClick() {
    if (widget.entry.isSelectable)
      openHierarchyManager.selectedEntry = widget.entry;
    if (widget.entry.isOpenable)
      onOpenFile();
    if (widget.entry.isCollapsible)
      toggleCollapsed();
  }

  void onOpenFile() {
    // Future.delayed(Duration(milliseconds: 75), () => setState(() => isClicked = false));
    // print("double");
  }

  void toggleCollapsed() {
    widget.entry.isCollapsed = !widget.entry.isCollapsed;
  }
}
