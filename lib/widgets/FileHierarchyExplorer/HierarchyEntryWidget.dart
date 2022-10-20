
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../customTheme.dart';
import '../../fileTypeUtils/dat/datRepacker.dart';
import '../../fileTypeUtils/pak/pakRepacker.dart';
import '../../fileTypeUtils/yax/xmlToYax.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/miscValues.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils.dart';

class HierarchyEntryWidget extends ChangeNotifierWidget {
  final HierarchyEntry entry;
  final int depth;

  HierarchyEntryWidget(this.entry, {this.depth = 0})
    : super(key: Key(entry.uuid), notifiers: [entry, shouldAutoTranslate]);

  @override
  State<HierarchyEntryWidget> createState() => _HierarchyEntryState();
}

const entryIcons = {
  DatHierarchyEntry: Icon(Icons.folder, color: Color.fromRGBO(0xfd, 0xd8, 0x35, 1), size: 15),
  PakHierarchyEntry: Icon(Icons.source, color: Color.fromRGBO(0xff, 0x98, 0x00, 1), size: 15),
  HapGroupHierarchyEntry: Icon(Icons.workspaces, color: Color.fromRGBO(0x00, 0xbc, 0xd4, 1), size: 15),
  XmlScriptHierarchyEntry: Icon(Icons.description, color: Color.fromRGBO(0xff, 0x70, 0x43, 1), size: 15),
};

class _HierarchyEntryState extends ChangeNotifierState<HierarchyEntryWidget> {
  bool isHovered = false;
  bool isClicked = false;

  @override
  Widget build(BuildContext context) {
    Icon? icon = entryIcons[widget.entry.runtimeType];
    return Column(
      children: [
        setupContextMenu(
          child: optionallySetupSelectable(context,
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              height: 25,
              child: Row(
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
                  if (icon != null)
                    icon,
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
    var prefs = PreferencesData();
    return ContextMenuRegion(
      enableLongPress: false,
      contextMenu: GenericContextMenu(
        buttonConfigs: [
          if (widget.entry is XmlScriptHierarchyEntry) ...[ 
            ContextMenuButtonConfig(
              "Open",
              icon: Icon(Icons.open_in_new, size: 15,),
              onPressed: onOpenFile,
            ),
            ContextMenuButtonConfig(
                "Export YAX",
              icon: Icon(Icons.file_upload, size: 15,),
              onPressed: () {
                var xml = widget.entry as XmlScriptHierarchyEntry;
                xmlFileToYaxFile(xml.path);
              },
            ),
            ContextMenuButtonConfig(
              "Unlink",
              icon: Icon(Icons.close, size: 15,),
              onPressed: () => openHierarchyManager.unlinkScript(widget.entry as XmlScriptHierarchyEntry),
            ),
            ContextMenuButtonConfig(
              "Delete",
              icon: Icon(Icons.delete, size: 15,),
              onPressed: () => openHierarchyManager.deleteScript(widget.entry as XmlScriptHierarchyEntry),
            ),
          ],
          if (widget.entry is HapGroupHierarchyEntry) ...[
            ContextMenuButtonConfig(
              "New Script",
              icon: Icon(Icons.description, size: 15,),
              onPressed: () => openHierarchyManager.addScript(widget.entry, parentPath: (widget.entry as FileHierarchyEntry).path),
            ),
            ContextMenuButtonConfig(
              "New Group",
              icon: Icon(Icons.workspaces, size: 15,),
              onPressed: () => (widget.entry as HapGroupHierarchyEntry).addChild(),
            ),
            if (widget.entry.isEmpty)
              ContextMenuButtonConfig(
                "Remove",
                icon: Icon(Icons.remove, size: 16,),
                onPressed: () => (widget.entry as HapGroupHierarchyEntry).removeSelf(),
              ),
          ],
          if (widget.entry is PakHierarchyEntry) ...[
            ContextMenuButtonConfig(
              "Repack PAK",
              icon: Icon(Icons.file_upload, size: 15,),
              onPressed: () {
                var pak = widget.entry as PakHierarchyEntry;
                repackPak(pak.extractedPath);
              },
            ),
          ],
          if (widget.entry is DatHierarchyEntry) ...[
            ContextMenuButtonConfig(
              "Repack DAT",
              icon: Icon(Icons.file_upload, size: 15,),
              onPressed: () {
                if (prefs.dataExportPath?.value == null) {
                  showToast("No export path set; go to Settings to set an export path");
                  return;
                }
                var dat = widget.entry as DatHierarchyEntry;
                var datBaseName = basename(dat.extractedPath);
                var exportPath = join(prefs.dataExportPath!.value, getDatFolder(datBaseName), datBaseName);
                repackDat(dat.extractedPath, exportPath);
              },
            ),
          ],
          if (openHierarchyManager.contains(widget.entry))
            ContextMenuButtonConfig(
              "Close",
              icon: Icon(Icons.close, size: 14,),
              onPressed: () => openHierarchyManager.remove(widget.entry),
            ),
          if (widget.entry.isNotEmpty)
            ContextMenuButtonConfig(
              "Collapse all",
              icon: Icon(Icons.unfold_less, size: 15,),
              onPressed: () => widget.entry.setCollapsedRecursive(true),
            ),
          if (widget.entry.isNotEmpty)
            ContextMenuButtonConfig(
              "Expand all",
              icon: Icon(Icons.unfold_more, size: 15,),
              onPressed: () => widget.entry.setCollapsedRecursive(false, true),
            ),
        ],
      ),
      child: child,
    );
  }

  Widget optionallySetupSelectable(BuildContext context, Widget child) {
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
    var entry = widget.entry as FileHierarchyEntry;
    String? secondaryName = entry is XmlScriptHierarchyEntry
      ? tryToTranslate(entry.hapName)
      : null;
    areasManager.openFile(entry.path, secondaryName: secondaryName);
  }

  void toggleCollapsed() {
    widget.entry.isCollapsed = !widget.entry.isCollapsed;
  }
}
