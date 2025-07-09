
import 'package:flutter/material.dart';

import '../../fileSystem/FileSystem.dart';
import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../../stateManagement/hierarchy/types/BnkHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/BxmHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/CtxHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/DatHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/EstHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/McdHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/PakHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/RubyScriptHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/SaveSlotDataHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/SmdHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/TmdHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/UidHierarchyData.dart';
import '../../stateManagement/hierarchy/types/WaiHierarchyEntries.dart';
import '../../stateManagement/hierarchy/types/WmbHierarchyData.dart';
import '../../stateManagement/hierarchy/types/WtaHierarchyEntry.dart';
import '../../stateManagement/hierarchy/types/WtbHierarchyEntry.dart';
import '../../stateManagement/miscValues.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/contextMenuBuilder.dart';
import 'wemPreviewButton.dart';

class HierarchyEntryWidget extends ChangeNotifierWidget {
  final HierarchyEntry entry;
  final int depth;
  static const height = 25.0;

  HierarchyEntryWidget({ required this.entry, Key? key, this.depth = 0 })
    : super(key: key ?? Key(entry.uuid), notifiers: [entry.isCollapsed, entry.isSelected, entry.name, openHierarchyManager.selectedEntry, shouldAutoTranslate, openHierarchyManager.search]);

  @override
  State<HierarchyEntryWidget> createState() => _HierarchyEntryState();
}

class _HierarchyEntryState extends ChangeNotifierState<HierarchyEntryWidget> {
  Icon? getEntryIcon(BuildContext context) {
    var iconColor = getTheme(context).colorOfFiletype(widget.entry);
    if (widget.entry is DatHierarchyEntry || widget.entry is WaiFolderHierarchyEntry)
      return Icon(Icons.folder, color: iconColor, size: 15);
    else if (widget.entry is PakHierarchyEntry || widget.entry is WspHierarchyEntry || widget.entry is CtxHierarchyEntry)
      return Icon(Icons.source, color: iconColor, size: 15);
    else if (widget.entry is HapGroupHierarchyEntry)
      return Icon(Icons.workspaces, color: iconColor, size: 15);
    else if (widget.entry is TmdHierarchyEntry || widget.entry is SmdHierarchyEntry || widget.entry is McdHierarchyEntry)
      return Icon(Icons.subtitles, color: iconColor, size: 15);
    else if (widget.entry is RubyScriptGroupHierarchyEntry)
      return null;
    else if (widget.entry is EstHierarchyEntry)
      return Icon(Icons.flare, color: iconColor, size: 15);
    else if (widget.entry is BxmHierarchyEntry)
      return Icon(Icons.code, color: iconColor, size: 15);
    else if (widget.entry is WtaHierarchyEntry || widget.entry is WtbHierarchyEntry)
      return Icon(Icons.photo_library, color: iconColor, size: 15);
    else if (widget.entry is WemHierarchyEntry)
      return Icon(Icons.music_note, color: iconColor, size: 15);
    else if (widget.entry is BnkHierarchyEntry)
      return Icon(Icons.queue_music, color: iconColor, size: 15);
    else if (widget.entry is SaveSlotDataHierarchyEntry)
      return Icon(Icons.save, color: iconColor, size: 15);
    else if (widget.entry is UidHierarchyEntry)
      return Icon(Icons.widgets, color: iconColor, size: 15);
    else if (widget.entry is WmbHierarchyEntry)
      return Icon(Icons.view_in_ar, color: iconColor, size: 15);
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
    else if (widget.entry is BnkSubCategoryParentHierarchyEntry) {
      var isFolder = (widget.entry as BnkSubCategoryParentHierarchyEntry).isFolder;
      if (isFolder)
        return Icon(Icons.folder, color: iconColor, size: 15);
      else
        return Icon(Icons.list, color: iconColor, size: 15);
    } else
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
    return setupWrapper(
      context: context,
      builder: (context, isDirty, hasSavedChanges) {
        var isDirtyColor = getTheme(context).actionTypeBlockingAccent;
        var hasSavedChangesColor = getTheme(context).textColor;
        return Container(
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
                child: ChangeNotifierBuilder(
                  notifiers: [widget.entry.name, openHierarchyManager.search],
                  builder: (context) => RichText(
                    textScaleFactor: 0.85,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: isDirty ? isDirtyColor : getTextColor(context)),
                      children: openHierarchyManager.search.value.isEmpty
                        ? [TextSpan(text: widget.entry.name.toString())]
                        : getHighlightedTextSpans(
                            widget.entry.name.toString(),
                            openHierarchyManager.search.value,
                            Theme.of(context).textTheme.bodyMedium!.copyWith(color: isDirty ? isDirtyColor : getTextColor(context)),
                          )
                    ),
                  ),
                )
              ),
              if (isDirty || hasSavedChanges)
                Tooltip(
                  message: isDirty ? "Unsaved changes" : "Changes saved",
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      isDirty ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: isDirty ? isDirtyColor : hasSavedChangesColor,
                    ),
                  ),
                ),
              if (widget.entry is WemHierarchyEntry)
                WemPreviewButton(wemPath: (widget.entry as WemHierarchyEntry).path),
            ]
          ),
        );
      },
	  );
  }

  Widget setupWrapper({required BuildContext context, required Widget Function(BuildContext context, bool isDirty, bool hasSavedChanges) builder}) {
    return setupContextMenu(
      child: optionallySetupSelectable(
        context: context,
        child: optionallySetupIsDirtyListener(
          context: context,
          builder: builder,
        ),
      ),
    );
  }

  Widget setupContextMenu({ required Widget child }) {
    return ContextMenu(
      configBuilder: () => widget.entry.getContextMenuActions()
        .map((action) => ContextMenuConfig(
          label: action.name,
          icon: Icon(action.icon, size: 15 * action.iconScale,),
          action: () => action.action(),
        ))
        .toList(),
      child: child,
    );
  }

  Widget optionallySetupSelectable({required BuildContext context, required Widget child}) {
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

  Widget optionallySetupIsDirtyListener({required BuildContext context, required Widget Function(BuildContext context, bool isDirty, bool hasSavedChanges) builder}) {
    return ChangeNotifierBuilder(
      notifiers: [widget.entry.isDirty, widget.entry.hasSavedChanges],
      builder: (context) => builder(context, widget.entry.isDirty.value, widget.entry.hasSavedChanges.value),
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

  List<TextSpan> getHighlightedTextSpans(String text, String query, TextStyle style) {
    var regex = RegExp(RegExp.escape(query), caseSensitive: false);
    List<TextSpan> textSpans = text.split(regex)
      .map((e) => TextSpan(text: e))
      .toList();
    List<String> fillStrings = regex.allMatches(text)
      .map((e) => e.group(0)!)
      .toList();
    for (int i = 1; i < textSpans.length; i += 2) {
      textSpans.insert(i, TextSpan(
        text: fillStrings[(i - 1) ~/ 2],
        style: style.copyWith(
          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.35),
        ),
      ));
    }
    return textSpans;
  }
}
