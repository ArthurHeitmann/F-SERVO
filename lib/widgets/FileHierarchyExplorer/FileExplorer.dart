
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/miscValues.dart';
import 'HierarchyEntryWidget.dart';

class FileExplorer extends ChangeNotifierWidget {
  FileExplorer({super.key}) : super(notifier: openHierarchyManager);

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends ChangeNotifierState<FileExplorer> {
  bool isDroppingFile = false;

  void openFile(DropDoneDetails details) {
    for (var file in details.files) {
      openHierarchyManager.openFile(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) => setState(() => isDroppingFile = true),
      onDragExited: (details) => setState(() => isDroppingFile = false),
      onDragDone: (details) {
        isDroppingFile = false;
        openFile(details);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          makeTopRow(),
          Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  children: openHierarchyManager
                    .map((element) => HierarchyEntryWidget(element))
                    .toList(),
                ),
                if (openHierarchyManager.isEmpty)
                  Center(
                    child: Text("No files open"),
                  ),
                if (isDroppingFile)
                  makeItemHoveredIndicator()
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget makeTopRow() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Text("FILE EXPLORER", 
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Row(
          children: [
            Tooltip(
              message: "Auo translate Jap to Eng",
              waitDuration: Duration(milliseconds: 500),
              child: ValueListenableBuilder(
                valueListenable: shouldAutoTranslate,
                builder: (_, __, ___) => Opacity(
                  opacity: shouldAutoTranslate.value ? 1.0 : 0.25,
                  child: IconButton(
                    padding: EdgeInsets.all(5),
                    constraints: BoxConstraints(),
                    iconSize: 20,
                    splashRadius: 20,
                    icon: Icon(Icons.translate),
                    isSelected: shouldAutoTranslate.value,
                    onPressed: () => shouldAutoTranslate.value ^= true,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: "Expand all",
              waitDuration: Duration(milliseconds: 500),
              child: IconButton(
                padding: EdgeInsets.all(5),
                constraints: BoxConstraints(),
                iconSize: 20,
                splashRadius: 20,
                icon: Icon(Icons.unfold_more),
                onPressed: openHierarchyManager.expandAll,
              ),
            ),
            Tooltip(
              message: "Collapse all",
              waitDuration: Duration(milliseconds: 500),
              child: IconButton(
                padding: EdgeInsets.all(5),
                constraints: BoxConstraints(),
                iconSize: 20,
                splashRadius: 20,
                icon: Icon(Icons.unfold_less),
                onPressed: openHierarchyManager.collapseAll,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget makeItemHoveredIndicator() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: getTheme(context).dropTargetColor,
        child: Center(
          child: Text(
            'Drop file here',
            style: TextStyle(
              color: getTheme(context).dropTargetTextColor,
              fontSize: 20,
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ),
    );
  }
}