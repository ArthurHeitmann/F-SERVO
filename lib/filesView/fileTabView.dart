import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:nier_scripts_editor/filesView/FileTabEntry.dart';
import 'package:nier_scripts_editor/filesView/TextFileEditor.dart';
import 'package:nier_scripts_editor/stateManagement/openFilesManager.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';


class FileTabView extends ChangeNotifierWidget {
  final FilesAreaManager viewArea;
  
  FileTabView(this.viewArea, {Key? key}) : 
    super(key: key, notifier: viewArea);

  @override
  State<FileTabView> createState() => _FileTabViewState();
}

class _FileTabViewState extends ChangeNotifierState<FileTabView> {
  bool isDroppingFile = false;
  // Map<OpenFileData, Widget> cachedEditors = {};

  void openFiles(List<XFile> files) async {
    if (files.isEmpty)
      return;
    OpenFileData? lastFile;
    for (var file in files) {
      if (areasManager.isFileOpened(file.path))
        continue;
      var newFileData = OpenFileData(file.name, file.path);
      widget.viewArea.add(newFileData);
      lastFile = newFileData;
    }
    if (lastFile != null)
      widget.viewArea.currentFile = lastFile;
    setState(() {});
  }

  // void pruneCachedWidgets() {
  //   var toRemove = <OpenFileData>[];
  //   for (var entry in cachedEditors.entries) {
  //     if (entry.key != widget.viewArea.currentFile && !widget.viewArea.contains(entry.key)) {
  //       toRemove.add(entry.key);
  //     }
  //   }
   
  //   for (var key in toRemove)
  //     cachedEditors.remove(key);
  // }

  Widget getOrMakeFileTabEntry(OpenFileData file) {
    // if (cachedEditors.containsKey(file))
    //   return cachedEditors[file]!;
    var newEntry = TextFileEditor(
      key: Key(widget.viewArea.currentFile!.uuid),
      file: widget.viewArea.currentFile!
    );
    // cachedEditors[file] = newEntry;
    return newEntry;
  }

  @override
  Widget build(BuildContext context) {
    // pruneCachedWidgets();

    return DropTarget(
      onDragEntered: (details) => setState(() => isDroppingFile = true),
      onDragExited: (details) => setState(() => isDroppingFile = false),
      onDragDone: (details) {
        isDroppingFile = false;
        openFiles(details.files);
      },
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              onReorder: (int oldIndex, int newIndex) => widget.viewArea.move(oldIndex, newIndex),
              buildDefaultDragHandles: false,
              children: widget.viewArea
                .map((file,) => ReorderableDragStartListener(
                  key: Key(file.uuid),
                  index: widget.viewArea.indexOf(file),
                  child: FileTabEntry(
                    file: file,
                    area: widget.viewArea
                  ),
                )
                )
                .toList(),
            ),
          ),
          Expanded(
            child: Center(
              child: widget.viewArea.currentFile != null
                ? getOrMakeFileTabEntry(widget.viewArea.currentFile!)
                : Text('No file open'),
            ),
          ),
        ]
      ),
    );
  }
}

