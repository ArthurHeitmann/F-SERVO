import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:nier_scripts_editor/filesView/FileTabEntry.dart';
import 'package:nier_scripts_editor/filesView/openFilesManager.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';


class FileTabView extends ChangeNotifierWidget {
  final FilesAreaManager viewArea;
  
  const FileTabView(this.viewArea, {Key? key}) : 
    super(key: key, notifier: viewArea);

  @override
  State<FileTabView> createState() => _FileTabViewState();
}

class _FileTabViewState extends ChangeNotifierState<FileTabView> {
  bool isDroppingFile = false;

  void openFiles(List<XFile> files) async {
    if (files.isEmpty)
      return;
    OpenFileData? lastFile;
    for (var file in files) {
      var newFileData = OpenFileData(file.name, file.path);
      widget.viewArea.add(newFileData);
      lastFile = newFileData;
    }
    widget.viewArea.currentFile = lastFile;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
                  key: Key(file.path),
                  index: widget.viewArea.indexOf(file),
                  child: FileTabEntry(
                    file: file,
                    area: widget.viewArea
                  ),
                )
                )
                .toList(),
              // itemCount: widget.viewArea.length,
              // itemBuilder: (context, i) => FileTabEntry(
              //   file: widget.viewArea[i],
              //   area: widget.viewArea,
              // ),
              // separatorBuilder: (BuildContext context, int index) 
              //   => Container(
              //     width: 1,
              //     constraints: BoxConstraints(maxHeight: 10),
              //     color: Color.fromARGB(255, 36, 36, 36)
              //   ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(widget.viewArea.currentFile?.path ?? "Open a file to edit")
            ),
          ),
        ]
      ),
    );
  }
}

