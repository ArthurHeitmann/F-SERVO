import 'package:flutter/material.dart';

import '../../stateManagement/changesExporter.dart';
import '../../stateManagement/openFiles/filesAreaManager.dart';
import '../../stateManagement/openFiles/openFileTypes.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/contextMenuBuilder.dart';
import '../misc/onHoverBuilder.dart';


class FileTabEntry extends ChangeNotifierWidget {
  final OpenFileId file;
  final FilesAreaManager area;
  
  FileTabEntry({super.key, required OpenFileData file, required this.area})
    : file = file.uuid,
    super(notifiers: [area.currentFile, file.name, file.secondaryName, file.hasUnsavedChanges]);

  @override
  State<FileTabEntry> createState() => _FileTabEntryState();
}

class _FileTabEntryState extends ChangeNotifierState<FileTabEntry> {
  @override
  Widget build(BuildContext context) {
    var file = areasManager.fromId(widget.file);
    if (file == null)
      return const SizedBox();
    return logicWrapper(
      file,
      SizedBox(
        width: 200,
        child: Padding(
          padding: const EdgeInsets.only(left: 2.5, right: 2.5, bottom: 3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: widget.file == widget.area.currentFile.value?.uuid ? getTheme(context).tabSelectedColor : getTheme(context).tabColor,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (file.icon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(file.icon, size: 15, color: file.iconColor),
                      ),
                    Expanded(child: 
                      Tooltip(
                        message: "${file.displayName}\n${file.path}",
                        waitDuration: const Duration(milliseconds: 500),
                        child: Text(
                          file.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    OnHoverBuilder(
                      builder: (cxt, isHovering) => IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: file.hasUnsavedChanges.value && !isHovering
                                ? const Icon(Icons.circle, key: ValueKey(1), size: 11,)
                                : const Icon(Icons.close, key: ValueKey(2))
                        ),
                        onPressed: () => widget.area.closeFile(file),
                        iconSize: 15,
                        splashRadius: 15,
                        color: getTheme(context).tabIconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget logicWrapper(OpenFileData file, Widget child) {
    return ContextMenu(
      config: [
        ContextMenuConfig(
          label: "Save",
          icon: const Icon(Icons.save, size: 14),
          action: () async {
            var file = areasManager.fromId(widget.file)!;
            await file.save();
            await processChangedFiles();
          },
        ),
        if (file.canBeReloaded)
          ContextMenuConfig(
            label: "Reload",
            icon: const Icon(Icons.refresh, size: 15),
            action: () => areasManager.fromId(widget.file)!.reload(),
          ),
        if (isDesktop)
          ContextMenuConfig(
            label: "Copy path",
            icon: const Icon(Icons.link, size: 15),
            action: () => copyToClipboard(areasManager.fromId(widget.file)!.path),
          ),
        if (isDesktop)
          ContextMenuConfig(
            label: "Show in Explorer",
            icon: const Icon(Icons.folder_open, size: 14),
            action: () => revealFileInExplorer(areasManager.fromId(widget.file)!.path),
          ),
        if (isWeb)
          ContextMenuConfig(
            label: "Download",
            icon: const Icon(Icons.download, size: 14),
            action: () => downloadFile(areasManager.fromId(widget.file)!.path),
          ),
        ContextMenuConfig(
          label: "Close",
          icon: const Icon(Icons.close, size: 11),
          action: () => widget.area.closeFile(areasManager.fromId(widget.file)!),
        ),
        ContextMenuConfig(
          label: "Close others",
          icon: const Icon(Icons.close, size: 13),
          action: () => widget.area.closeOthers(areasManager.fromId(widget.file)!),
        ),
        ContextMenuConfig(
          label: "Close all",
          icon: const Icon(Icons.close, size: 15),
          action: () => widget.area.closeAll(),
        ),
        ContextMenuConfig(
          label: "Close to the left",
          icon: const Icon(Icons.chevron_left, size: 14),
          action: () => widget.area.closeToTheLeft(areasManager.fromId(widget.file)!),
        ),
        ContextMenuConfig(
          label: "Close to the right",
          icon: const Icon(Icons.chevron_right, size: 14),
          action: () => widget.area.closeToTheRight(areasManager.fromId(widget.file)!),
        ),
        ContextMenuConfig(
          label: "Move to left view",
          icon: const Icon(Icons.arrow_back, size: 14),
          action: () => widget.area.moveToLeftView(areasManager.fromId(widget.file)!),
        ),
        ContextMenuConfig(
          label: "Move to right view",
          icon: const Icon(Icons.arrow_forward, size: 14),
          action: () => widget.area.moveToRightView(areasManager.fromId(widget.file)!),
        ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.area.setCurrentFile(areasManager.fromId(widget.file)!),
          onTertiaryTapUp: (_) => widget.area.closeFile(areasManager.fromId(widget.file)!),
          child: child,
        ),
      ),
    );
  }
}
