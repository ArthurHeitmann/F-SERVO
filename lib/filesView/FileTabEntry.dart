import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/stateManagement/openFilesManager.dart';


class FileTabEntry extends StatelessWidget {
  final OpenFileData file;
  final FilesAreaManager area;
  
  const FileTabEntry({Key? key, required this.file, required this.area}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return logicWrapper(
      SizedBox(
        width: 150,
        child: Material(
          color: file == area.currentFile ? Color.fromARGB(255, 36, 36, 36) : Color.fromARGB(255, 59, 59, 59),
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child:
                  Text(
                    file.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: Icon(Icons.close),
                  onPressed: () => area.closeFile(file),
                  iconSize: 15,
                  splashRadius: 15,
                  color: Color.fromRGBO(255, 255, 255, 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget logicWrapper(Widget child) {
    return ContextMenuRegion(
      contextMenu: GenericContextMenu(
        buttonConfigs: [
          ContextMenuButtonConfig(
            "Close",
            onPressed: () => area.closeFile(file),
          ),
          ContextMenuButtonConfig(
            "Close others",
            onPressed: () => area.closeOthers(file),
          ),
          ContextMenuButtonConfig(
            "Close all",
            onPressed: () => area.closeAll(),
          ),
          ContextMenuButtonConfig(
            "Close to the left",
            onPressed: () => area.closeToTheLeft(file),
          ),
          ContextMenuButtonConfig(
            "Close to the right",
            onPressed: () => area.closeToTheRight(file),
          ),
          ContextMenuButtonConfig(
            "Move to left view",
            onPressed: () => area.moveToLeftView(file),
          ),
          ContextMenuButtonConfig(
            "Move to right view",
            onPressed: () => area.moveToRightView(file),
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => area.currentFile = file,
          onTertiaryTapUp: (_) => area.closeFile(file),
          child: child,
        ),
      ),
    );
  }
}
