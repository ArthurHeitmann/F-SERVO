
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../stateManagement/statusInfo.dart';
import '../../utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/miscValues.dart';
import '../misc/SmoothScrollBuilder.dart';
import 'HierarchyEntryWidget.dart';

class FileExplorer extends ChangeNotifierWidget {
  FileExplorer({super.key}) : super(notifier: openHierarchyManager);

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends ChangeNotifierState<FileExplorer> {
  bool isDroppingFile = false;

  void openFile(DropDoneDetails details) async {
    List<Future> futures = [];

    for (var file in details.files) {
      futures.add(openHierarchyManager.openFile(file.path));
    }

    await Future.wait(futures);

    messageLog.add("Opened ${pluralStr(details.files.length, "file")}");
  }

  Future<void> openFilePicker() async {
    var files = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (files == null)
      return;

    await Future.wait(
      files.files.map((f) => openHierarchyManager.openFile(f.path!))
    );

    messageLog.add("Opened ${pluralStr(files.files.length, "file")}");
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
          const Divider(height: 1),
          makeTopRow(),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                SmoothSingleChildScrollView(
                  controller: ScrollController(),
                  stepSize: 60,
                  child: Column(
                    children: openHierarchyManager
                      .map((element) => HierarchyEntryWidget(element))
                      .toList(),
                  ),
                ),
                if (openHierarchyManager.isEmpty)
                  const Center(
                    child: Text("No files open"),
                  ),
                if (isDroppingFile)
                  makeItemHoveredIndicator()
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget makeTopRow() {
    return Row(
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
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
              message: "Open file",
              waitDuration: const Duration(milliseconds: 500),
              child: IconButton(
                padding: const EdgeInsets.all(5),
                constraints: const BoxConstraints(),
                iconSize: 20,
                splashRadius: 20,
                icon: const Icon(Icons.folder_open, size: 15,),
                onPressed: openFilePicker,
              ),
            ),
            Tooltip(
              message: "Auto translate Jap to Eng",
              waitDuration: const Duration(milliseconds: 500),
              child: ChangeNotifierBuilder(
                notifier: shouldAutoTranslate,
                builder: (context) => Opacity(
                  opacity: shouldAutoTranslate.value ? 1.0 : 0.25,
                  child: IconButton(
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                    splashRadius: 20,
                    icon: const Icon(Icons.translate, size: 15,),
                    isSelected: shouldAutoTranslate.value,
                    onPressed: () => shouldAutoTranslate.value ^= true,
                  ),
                ),
              ),
            ),
            Tooltip(
              message: "Expand all",
              waitDuration: const Duration(milliseconds: 500),
              child: IconButton(
                padding: const EdgeInsets.all(5),
                constraints: const BoxConstraints(),
                iconSize: 20,
                splashRadius: 20,
                icon: const Icon(Icons.unfold_more, size: 17),
                onPressed: openHierarchyManager.expandAll,
              ),
            ),
            Tooltip(
              message: "Collapse all",
              waitDuration: const Duration(milliseconds: 500),
              child: IconButton(
                padding: const EdgeInsets.all(5),
                constraints: const BoxConstraints(),
                iconSize: 20,
                splashRadius: 20,
                icon: const Icon(Icons.unfold_less, size: 17),
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
              color: getTheme(context).textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ),
    );
  }
}
