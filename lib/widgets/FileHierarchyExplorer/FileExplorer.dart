
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../propEditors/UnderlinePropTextField.dart';
import '../propEditors/propEditorFactory.dart';
import '../propEditors/propTextField.dart';
import 'HierarchyFlatList.dart';

class FileExplorer extends ChangeNotifierWidget {
  FileExplorer({super.key}) : super(notifiers: [openHierarchyManager.children, openHierarchySearch]);

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends ChangeNotifierState<FileExplorer> {
  final scrollController = ScrollController();
  bool isDroppingFile = false;
  bool expandSearch = false;

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
                HierarchyFlatList(),
                if (openHierarchyManager.children.isEmpty)
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
        if (!expandSearch)
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
        if (expandSearch) ...[
          const SizedBox(width: 8),
          Expanded(
            child: makePropEditor<UnderlinePropTextField>(
              openHierarchySearch, const PropTFOptions(useIntrinsicWidth: false, hintText: "Search..."),
            )
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          icon: const Icon(Icons.search),
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(),
          iconSize: 16,
          splashRadius: 20,
          onPressed: () => setState(() {
            expandSearch = !expandSearch;
            if (!expandSearch)
              openHierarchySearch.value = "";
          }),
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
