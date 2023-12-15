
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../stateManagement/miscValues.dart';
import '../../utils/utils.dart';
import 'wemPreviewButton.dart';

class HierarchyEntryWidget extends ChangeNotifierWidget {
  final HierarchyEntry entry;
  final int depth;
  static const height = 25.0;

  HierarchyEntryWidget({ required this.entry, Key? key, this.depth = 0 })
    : super(key: key ?? Key(entry.uuid), notifiers: [entry.isCollapsed, entry.isSelected, entry.name, openHierarchyManager.selectedEntry, shouldAutoTranslate, openHierarchySearch]);

  @override
  State<HierarchyEntryWidget> createState() => _HierarchyEntryState();
}

class _HierarchyEntryState extends ChangeNotifierState<HierarchyEntryWidget> {
  Icon? getEntryIcon(BuildContext context) {
    var iconColor = getTheme(context).colorOfFiletype(widget.entry);
    if (widget.entry is DatHierarchyEntry || widget.entry is WaiFolderHierarchyEntry)
      return Icon(Icons.folder, color: iconColor, size: 15);
    else if (widget.entry is PakHierarchyEntry || widget.entry is WspHierarchyEntry)
      return Icon(Icons.source, color: iconColor, size: 15);
    else if (widget.entry is HapGroupHierarchyEntry)
      return Icon(Icons.workspaces, color: iconColor, size: 15);
    else if (widget.entry is TmdHierarchyEntry || widget.entry is SmdHierarchyEntry || widget.entry is McdHierarchyEntry)
      return Icon(Icons.subtitles, color: iconColor, size: 15);
    else if (widget.entry is RubyScriptGroupHierarchyEntry)
      return null;
    else if (widget.entry is WemHierarchyEntry)
      return Icon(Icons.music_note, color: iconColor, size: 15);
    else if (widget.entry is BnkHierarchyEntry)
      return Icon(Icons.queue_music, color: iconColor, size: 15);
    else if (widget.entry is SaveSlotDataHierarchyEntry)
      return Icon(Icons.save, color: iconColor, size: 15);
    else if (widget.entry is BnkHircHierarchyEntry) {
      var entryType = (widget.entry as BnkHircHierarchyEntry).type;
      if (entryType == "WEM")
        return Icon(Icons.music_note, color: iconColor, size: 15);
      else if (entryType == "Sound")
        return Icon(Icons.volume_up, color: iconColor, size: 15);
      else if (entryType == "MusicTrack")
        return Icon(Icons.volume_up, color: iconColor, size: 15);
      else if (entryType == "MusicPlaylist")
        return Icon(Icons.queue_music, color: iconColor, size: 15);
      else if (entryType == "Event")
        return Icon(Icons.priority_high, color: iconColor, size: 15);
      else if (entryType == "MusicSwitch")
        return Icon(Icons.account_tree, color: iconColor, size: 15);
      else if (entryType == "SwitchAssoc")
        return Icon(Icons.account_tree_outlined, color: iconColor, size: 15);
      else if (entryType == "Action")
        return Icon(Icons.keyboard_double_arrow_right, color: iconColor, size: 15);
      else if (entryType == "StateGroup")
        return Icon(Icons.workspaces, color: iconColor, size: 15);
      else if (entryType == "State")
        return Icon(Icons.trip_origin, color: iconColor, size: 15);
      else if (entryType == "ActionTarget")
        return Icon(Icons.arrow_right_alt, color: iconColor, size: 15);
      else
        return Icon(Icons.list, color: iconColor, size: 15);
    }
    else
      return Icon(Icons.description, color: iconColor, size: 15);
  }

  Color getTextColor(BuildContext context) {
    return widget.entry.isSelected.value
      ? getTheme(context).hierarchyEntrySelectedTextColor!
      : getTheme(context).textColor!;
  }

  @override
  Widget build(BuildContext context) {
    Icon? icon = getEntryIcon(context);
    return setupContextMenu(
      child: optionallySetupSelectable(context,
        Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          height: HierarchyEntryWidget.height,
          child: Row(
            children: [
              SizedBox(width: 15.0 * widget.depth,),
              if (widget.entry.isCollapsible)
                Padding(
                  padding: const EdgeInsets.only(right: 4, left: 2),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      maxWidth: 14
                    ),
                    splashRadius: 14,
                    onPressed: toggleCollapsed,
                    icon: Icon(
                      widget.entry.isCollapsed.value ? Icons.chevron_right : Icons.expand_more,
                      size: 17,
                      color: getTextColor(context)
                    ),
                  ),
                )
              else if (widget.depth == 0)
                const SizedBox(width: 4),
              if (icon != null)
                icon,
              const SizedBox(width: 5),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: widget.entry.name,
                  builder: (context, name, child) =>  Text(
                    widget.entry.name.toString(),
                    overflow: TextOverflow.ellipsis,
                    textScaleFactor: 0.85,
                    style: TextStyle(
                      color: getTextColor(context)
                    ),
                  ),
                )
              ),
              if (widget.entry is WemHierarchyEntry)
                WemPreviewButton(wemPath: (widget.entry as WemHierarchyEntry).path),
            ]
          ),
        ),
      ),
	  );
  }

  Widget setupContextMenu({ required Widget child }) {
    return ContextMenuRegion(
      enableLongPress: isMobile,
      contextMenu: GenericContextMenu(
        buttonConfigs: widget.entry.getContextMenuActions()
          .map((action) => ContextMenuButtonConfig(
            action.name,
            icon: Icon(action.icon, size: 15 * action.iconScale,),
            onPressed: () => action.action(),
          ))
          .toList(),
      ),
      child: child,
    );
  }

  Widget optionallySetupSelectable(BuildContext context, Widget child) {
    if (!widget.entry.isSelectable && !widget.entry.isCollapsible)
      return child;
    
    var bgColor = widget.entry.isSelected.value ? getTheme(context).hierarchyEntrySelected! : Colors.transparent;

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: onClick,
        splashColor: getTextColor(context).withOpacity(0.2),
        hoverColor: getTextColor(context).withOpacity(0.1),
        highlightColor: getTextColor(context).withOpacity(0.1),
        child: child,
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
      onSelected();
    if (widget.entry.isOpenable && (!widget.entry.isSelectable || isDoubleClick()))
      widget.entry.onOpen();
    else if (widget.entry.isCollapsible && (!widget.entry.isSelectable || isDoubleClick()))
      toggleCollapsed();

    lastClickAt = DateTime.now().millisecondsSinceEpoch;
  }

  void onSelected() {
    if ((isShiftPressed() || isCtrlPressed()) && openHierarchyManager.selectedEntry.value == widget.entry)
      openHierarchyManager.setSelectedEntry(null);
    else
      openHierarchyManager.setSelectedEntry(widget.entry);
  }

  void toggleCollapsed() {
    widget.entry.isCollapsed.value = !widget.entry.isCollapsed.value;
  }
}
