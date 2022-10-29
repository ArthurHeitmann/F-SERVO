
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../fileTypeUtils/ruby/pythonRuby.dart';
import '../../widgets/theme/customTheme.dart';
import '../../fileTypeUtils/dat/datRepacker.dart';
import '../../fileTypeUtils/pak/pakRepacker.dart';
import '../../fileTypeUtils/yax/xmlToYax.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/miscValues.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/utils.dart';

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

  Icon? getEntryIcon(BuildContext context) {
    var iconColor = getTheme(context).colorOfFiletype(widget.entry);
    if (widget.entry is DatHierarchyEntry)
      return Icon(Icons.folder, color: iconColor, size: 15);
    else if (widget.entry is PakHierarchyEntry)
      return Icon(Icons.source, color: iconColor, size: 15);
    else if (widget.entry is HapGroupHierarchyEntry)
      return Icon(Icons.workspaces, color: iconColor, size: 15);
    else if (widget.entry is TmdHierarchyEntry || widget.entry is SmdHierarchyEntry || widget.entry is McdHierarchyEntry)
      return Icon(Icons.subtitles, color: iconColor, size: 15);
    else
      return Icon(Icons.description, color: iconColor, size: 15);
  }

  Color getTextColor(BuildContext context) {
    return isClicked || widget.entry.isSelected
      ? getTheme(context).hierarchyEntrySelectedTextColor!
      : getTheme(context).textColor!;
  }

  @override
  Widget build(BuildContext context) {
    Icon? icon = getEntryIcon(context);
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
                        constraints: const BoxConstraints(
                          maxWidth: 14
                        ),
                        splashRadius: 14,
                        onPressed: toggleCollapsed,
                        icon: Icon(
                          widget.entry.isCollapsed ? Icons.chevron_right : Icons.expand_more,
                          size: 17,
                          color: getTextColor(context)
                        ),
                      ),
                    ),
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
      enableLongPress: isMobile,
      contextMenu: GenericContextMenu(
        buttonConfigs: [
          if (widget.entry is XmlScriptHierarchyEntry) ...[ 
            ContextMenuButtonConfig(
              "Open",
              icon: const Icon(Icons.open_in_new, size: 15,),
              onPressed: onOpenFile,
            ),
            ContextMenuButtonConfig(
                "Export YAX",
              icon: const Icon(Icons.file_upload, size: 15,),
              onPressed: () {
                var xml = widget.entry as XmlScriptHierarchyEntry;
                xmlFileToYaxFile(xml.path);
              },
            ),
            ContextMenuButtonConfig(
              "Unlink",
              icon: const Icon(Icons.close, size: 15,),
              onPressed: () => openHierarchyManager.unlinkScript(widget.entry as XmlScriptHierarchyEntry),
            ),
            ContextMenuButtonConfig(
              "Delete",
              icon: const Icon(Icons.delete, size: 15,),
              onPressed: () => openHierarchyManager.deleteScript(widget.entry as XmlScriptHierarchyEntry),
            ),
          ],
          if (widget.entry is HapGroupHierarchyEntry) ...[
            ContextMenuButtonConfig(
              "New Script",
              icon: const Icon(Icons.description, size: 15,),
              onPressed: () => openHierarchyManager.addScript(widget.entry, parentPath: (widget.entry as FileHierarchyEntry).path),
            ),
            ContextMenuButtonConfig(
              "New Group",
              icon: const Icon(Icons.workspaces, size: 15,),
              onPressed: () => (widget.entry as HapGroupHierarchyEntry).addChild(),
            ),
            if (widget.entry.isEmpty)
              ContextMenuButtonConfig(
                "Remove",
                icon: const Icon(Icons.remove, size: 16,),
                onPressed: () => (widget.entry as HapGroupHierarchyEntry).removeSelf(),
              ),
          ],
          if (widget.entry is PakHierarchyEntry) ...[
            ContextMenuButtonConfig(
              "Repack PAK",
              icon: const Icon(Icons.file_upload, size: 15,),
              onPressed: () {
                var pak = widget.entry as PakHierarchyEntry;
                repackPak(pak.extractedPath);
              },
            ),
          ],
          if (widget.entry is DatHierarchyEntry) ...[
            ContextMenuButtonConfig(
              "Repack DAT",
              icon: const Icon(Icons.file_upload, size: 15,),
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
          if (widget.entry is RubyScriptHierarchyEntry) ...[
            ContextMenuButtonConfig(
              "Compile to .bin",
              icon: const Icon(Icons.file_upload, size: 15,),
              onPressed: () {
                var rbPath = (widget.entry as RubyScriptHierarchyEntry).path;
                rubyFileToBin(rbPath);
              },
            ),
          ],
          if (openHierarchyManager.contains(widget.entry)) ...[
            ContextMenuButtonConfig(
              "Close",
              icon: const Icon(Icons.close, size: 14,),
              onPressed: () => openHierarchyManager.remove(widget.entry),
            ),
            ContextMenuButtonConfig(
              "Close All",
              icon: const Icon(Icons.close, size: 14,),
              onPressed: () => openHierarchyManager.clear(),
            ),
          ],
          if (widget.entry.isNotEmpty)
            ContextMenuButtonConfig(
              "Collapse all",
              icon: const Icon(Icons.unfold_less, size: 15,),
              onPressed: () => widget.entry.setCollapsedRecursive(true),
            ),
          if (widget.entry.isNotEmpty)
            ContextMenuButtonConfig(
              "Expand all",
              icon: const Icon(Icons.unfold_more, size: 15,),
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
        child: Container(
          color: bgColor,
          // duration: const Duration(milliseconds: 75),
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
