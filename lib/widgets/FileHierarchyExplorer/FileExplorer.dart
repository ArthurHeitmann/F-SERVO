
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/dropTargetBuilder.dart';
import '../misc/selectionPopup.dart';
import '../propEditors/UnderlinePropTextField.dart';
import '../propEditors/propEditorFactory.dart';
import '../propEditors/propTextField.dart';
import 'HierarchyFlatList.dart';

class FileExplorer extends ChangeNotifierWidget {
  FileExplorer({super.key}) : super(notifiers: [openHierarchyManager.children, openHierarchyManager.search]);

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends ChangeNotifierState<FileExplorer> {
  bool expandSearch = false;

  void openFile(List<String> files) async {
    List<Future<HierarchyEntry?>> futures = [];

    for (var file in files) {
      futures.add(openHierarchyManager.openFile(file));
    }

    var openedFiles = await Future.wait(futures);
    var filesCount = openedFiles.where((f) => f != null).length;

    messageLog.add("Opened ${pluralStr(filesCount, "file")}");
  }

  Future<void> openFilePicker() async {
    var files = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (files == null)
      return;

    var openedFiles = await Future.wait(
      files.files.map((f) => openHierarchyManager.openFile(f.path!))
    );
    var filesCount = openedFiles.where((f) => f != null).length;

    messageLog.add("Opened ${pluralStr(filesCount, "file")}");
  }

  @override
  Widget build(BuildContext context) {
    return DropTargetBuilder(
      onDrop: (files) => openFile(files),
      builder: (context, isDropping) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          makeTopRow(context),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                HierarchyFlatList(),
                if (openHierarchyManager.children.isEmpty)
                  const Center(
                    child: Text("No files open"),
                  ),
                if (isDropping)
                  makeItemHoveredIndicator(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget makeTopRow(BuildContext context) {
    return Row(
      children: [
        if (!expandSearch)
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
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
              openHierarchyManager.search, const PropTFOptions(useIntrinsicWidth: false, hintText: "Search..."),
            )
          ),
          const SizedBox(width: 8),
        ],
        Tooltip(
          message: "Search",
          waitDuration: const Duration(milliseconds: 500),
          child: IconButton(
            icon: const Icon(Icons.search),
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(),
            iconSize: 16,
            splashRadius: 20,
            onPressed: () => setState(() {
              expandSearch = !expandSearch;
              if (!expandSearch)
                openHierarchyManager.search.value = "";
            }),
          ),
        ),
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
          message: "Open recent file",
          waitDuration: const Duration(milliseconds: 500),
          child: IconButton(
            icon: const Icon(Icons.history),
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(),
            iconSize: 16,
            splashRadius: 20,
            onPressed: () => showMostRecentFiles(context),
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
    );
  }

  Widget makeItemHoveredIndicator(BuildContext context) {
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

  void showMostRecentFiles(BuildContext context) async {
    var prefs = PreferencesData();
    var recentFiles = prefs.lastHierarchyFiles?.value ?? [];
    recentFiles = recentFiles
      .where((f) {
        try {
          return File(f).existsSync();
        } catch (e) {
          return false;
        }
      })
      .toList();
    var selectedPath = await showSelectionPopup(context, [
      for (var file in recentFiles)
        SelectionPopupConfig(name: trimFilePath(file, 40), key: Key(file), getValue: () => file)
    ]);
    if (selectedPath == null)
      return;
    await openHierarchyManager.openFile(selectedPath);
  }
}
