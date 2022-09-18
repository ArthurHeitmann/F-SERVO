import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/openFilesManager.dart';


class FileTabEntry extends ChangeNotifierWidget {
  final OpenFileData file;
  final FilesAreaManager area;
  
  FileTabEntry({Key? key, required this.file, required this.area}) : super(key: key, notifier: file);

  @override
  State<FileTabEntry> createState() => _FileTabEntryState();
}

class _FileTabEntryState extends ChangeNotifierState<FileTabEntry> {
  @override
  Widget build(BuildContext context) {
    return logicWrapper(
      SizedBox(
        width: 150,
        child: Padding(
          padding: const EdgeInsets.only(left: 2.5, right: 2.5, bottom: 3),
          child: Material(
            color: widget.file == widget.area.currentFile ? getTheme(context).tabSelectedColor : getTheme(context).tabColor,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child:
                    Text(
                      widget.file.name + (widget.file.hasUnsavedChanges ? "*" : ""),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: Icon(Icons.close),
                    onPressed: () => widget.area.closeFile(widget.file),
                    iconSize: 15,
                    splashRadius: 15,
                    color: getTheme(context).tabIconColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget logicWrapper(Widget child) {
    return ContextMenuRegion(
      enableLongPress: false,
      contextMenu: GenericContextMenu(
        buttonConfigs: [
          ContextMenuButtonConfig(
            "Close",
            onPressed: () => widget.area.closeFile(widget.file),
          ),
          ContextMenuButtonConfig(
            "Close others",
            onPressed: () => widget.area.closeOthers(widget.file),
          ),
          ContextMenuButtonConfig(
            "Close all",
            onPressed: () => widget.area.closeAll(),
          ),
          ContextMenuButtonConfig(
            "Close to the left",
            onPressed: () => widget.area.closeToTheLeft(widget.file),
          ),
          ContextMenuButtonConfig(
            "Close to the right",
            onPressed: () => widget.area.closeToTheRight(widget.file),
          ),
          ContextMenuButtonConfig(
            "Move to left view",
            onPressed: () => widget.area.moveToLeftView(widget.file),
          ),
          ContextMenuButtonConfig(
            "Move to right view",
            onPressed: () => widget.area.moveToRightView(widget.file),
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.area.currentFile = widget.file,
          onTertiaryTapUp: (_) => widget.area.closeFile(widget.file),
          child: child,
        ),
      ),
    );
  }
}
