import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:nier_scripts_editor/filesView/FileTabEntry.dart';
import 'package:nier_scripts_editor/filesView/TextFileEditor.dart';
import 'package:nier_scripts_editor/stateManagement/openFilesManager.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';
import 'package:window_manager/window_manager.dart';

import '../customTheme.dart';
import '../stateManagement/openFileContents.dart';
import '../utils.dart';


class FileTabView extends ChangeNotifierWidget {
  final FilesAreaManager viewArea;
  
  const FileTabView(this.viewArea, {Key? key}) : 
    super(key: key, notifier: viewArea);

  @override
  State<FileTabView> createState() => _FileTabViewState();
}

class _FileTabViewState extends ChangeNotifierState<FileTabView> {
  final FocusNode focusNode = FocusNode();
  bool isDroppingFile = false;
  Map<OpenFileData, Widget> cachedEditors = {};

  void openFiles(List<XFile> files) async {
    if (files.isEmpty)
      return;
    OpenFileData? firstFile;
    for (var file in files) {
      if (areasManager.isFileOpened(file.path))
        continue;
      var newFileData = OpenFileData(file.name, file.path);
      widget.viewArea.add(newFileData);
      firstFile ??= newFileData;
    }
    if (firstFile != null)
      widget.viewArea.currentFile = firstFile;
    windowManager.focus();
    setState(() {});
  }

  void pruneCachedWidgets() {
    var toRemove = <OpenFileData>[];
    for (var entry in cachedEditors.entries) {
      if (entry.key != widget.viewArea.currentFile && !widget.viewArea.contains(entry.key)) {
        toRemove.add(entry.key);
      }
    }
   
    for (var key in toRemove)
      cachedEditors.remove(key);
  }

  Widget getOrMakeFileEditor(OpenFileData file) {
    if (cachedEditors.containsKey(file))
      return cachedEditors[file]!;
    var fileContent = fileContentsManager.getContent(file) as FileTextContent;
    Widget newEntry = TextFileEditor(
      file: fileContent
    );
    newEntry = SingleChildScrollView(
      key: fileContent.key,
      controller: fileContent.scrollController,
      child: newEntry,
    );
    cachedEditors[file] = newEntry;
    return newEntry;
  }

  @override
  Widget build(BuildContext context) {
    pruneCachedWidgets();

    return DropTarget(
      onDragEntered: (details) => setState(() => isDroppingFile = true),
      onDragExited: (details) => setState(() => isDroppingFile = false),
      onDragDone: (details) {
        isDroppingFile = false;
        openFiles(details.files);
      },
      child: setupShortcuts(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 30,
              child: ReorderableListView(
                scrollController: ScrollController(),
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
              child: Stack(
                children: [
                  widget.viewArea.currentFile != null
                    ? getOrMakeFileEditor(widget.viewArea.currentFile!)
                    : Center(child: Text('No file open')),
                  if (isDroppingFile)
                   Positioned(
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
                  )
                ],
              ),
            ),
          ]
        ),
      ),
    );
  }

  Widget setupShortcuts({ required Widget child }) {
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: FocusableActionDetector(
        focusNode: focusNode,
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab): TabChangeIntent(HorizontalDirection.right, widget.viewArea),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.tab): TabChangeIntent(HorizontalDirection.left, widget.viewArea),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW): CloseTabIntent(widget.viewArea),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): SaveTabIntent(widget.viewArea),
        },
          // dispatcher: LoggingActionDispatcher(),
          actions: {
            TabChangeIntent: TabChangeAction(),
            CloseTabIntent: CloseTabAction(),
            SaveTabIntent: SaveTabAction(),
          },
          child: child,
        // ),
      ),
    );
  }
}

class TabChangeIntent extends Intent {
  final HorizontalDirection direction;
  final FilesAreaManager area;
  const TabChangeIntent(this.direction, this.area);
}

class CloseTabIntent extends Intent {
  final FilesAreaManager area;
  const CloseTabIntent(this.area);
}

class SaveTabIntent extends Intent {
  final FilesAreaManager area;
  const SaveTabIntent(this.area);
}

class TabChangeAction extends Action<TabChangeIntent> {
  TabChangeAction();

  @override
  void invoke(TabChangeIntent intent) {
    if (intent.direction == HorizontalDirection.right)
      intent.area.switchToNextFile();
    else
      intent.area.switchToPreviousFile();
  }
}

class CloseTabAction extends Action<CloseTabIntent> {
  CloseTabAction();

  @override
  void invoke(CloseTabIntent intent) {
    if (intent.area.currentFile != null)
      intent.area.closeFile(intent.area.currentFile!);
  }
}

class SaveTabAction extends Action<SaveTabIntent> {
  SaveTabAction();

  @override
  void invoke(SaveTabIntent intent) {
    if (intent.area.currentFile != null)
      print("Saving not implemented yet");
  }
}

/// An ActionDispatcher that logs all the actions that it invokes.
class LoggingActionDispatcher extends ActionDispatcher {
  @override
  Object? invokeAction(
    covariant Action<Intent> action,
    covariant Intent intent, [
    BuildContext? context,
  ]) {
    print('Action invoked: $action($intent) from $context');
    super.invokeAction(action, intent, context);

    return null;
  }
}
