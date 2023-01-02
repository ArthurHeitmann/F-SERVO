import 'dart:io';
import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

import '../../stateManagement/FileHierarchy.dart';
import '../../stateManagement/HierarchyEntryTypes.dart';
import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/events/statusInfo.dart';
import 'FileTabEntry.dart';
import 'FileType.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFilesManager.dart';
import '../../widgets/theme/customTheme.dart';
import '../../utils/utils.dart';


class FileTabView extends ChangeNotifierWidget {
  final FilesAreaManager viewArea;
  
  FileTabView(this.viewArea, {Key? key}) : 
    super(key: key, notifier: viewArea);

  @override
  State<FileTabView> createState() => _FileTabViewState();
}

class _FileTabViewState extends ChangeNotifierState<FileTabView> {
  ScrollController tabBarScrollController = ScrollController();
  String? prevActiveUuid;
  bool isDroppingFile = false;

  @override
  void onNotified() {
    var newActiveUuid = widget.viewArea.currentFile?.uuid;
    if (prevActiveUuid != newActiveUuid && newActiveUuid != null)
      scrollTabIntoView(newActiveUuid);
    prevActiveUuid = newActiveUuid;

    super.onNotified();
  }

  void scrollTabIntoView(String uuid) {
    var viewWidth = (context.findRenderObject() as RenderBox).size.width;
    
    var fileData = widget.viewArea.firstWhere((f) => f.uuid == uuid);
    var index = widget.viewArea.indexOf(fileData);
    var tabPos = max(0.0, index * 150.0 - 15);
    var tabEnd = tabPos + 150.0 + 30;

    var scrollAreaStart = tabBarScrollController.offset;
    var scrollAreaEnd = tabBarScrollController.offset + viewWidth;

    if (tabPos < scrollAreaStart)
      tabBarScrollController.animateTo(tabPos, duration: const Duration(milliseconds: 250), curve: Curves.ease);
    else if (tabEnd > scrollAreaEnd)
      tabBarScrollController.animateTo(tabEnd - viewWidth, duration: const Duration(milliseconds: 250), curve: Curves.ease);
  }

  void openFiles(List<XFile> files) async {
    if (files.isEmpty)
      return;
    OpenFileData? firstFile;
    const fileExplorerExtensions = { ".pak", ".dat", ".yax", ".bin", ".wai", ".wsp", ".bxm", ".gad", ".sar", ".bnk" };
    for (var file in files) {
      if (fileExplorerExtensions.contains(path.extension(file.name)) || await Directory(file.path).exists()) {
        var entry = await openHierarchyManager.openFile(file.path);
        if (entry is XmlScriptHierarchyEntry)
          areasManager.openFile(entry.path);
        continue;
      }
      var newFileData = areasManager.openFile(file.path, toArea: widget.viewArea);
      firstFile ??= newFileData;
    }
    if (firstFile != null)
      widget.viewArea.currentFile = firstFile;
    windowManager.focus();
    setState(() {});

    messageLog.add("Opened ${pluralStr(files.length, "file")}");
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
      child: setupShortcuts(
        child: Stack(
          children: [
            Positioned.fill(
              child: widget.viewArea.currentFile != null
                ? makeFilesStack(context)
                : makeEmptyTab(context),
            ),
            makeTabBar(),
          ],
        ),
      ),
    );
  }

  Widget setupShortcuts({ required Widget child }) {
    return Listener(
      // onTapDown: (_) => areasManager.activeArea = widget.viewArea,
      onPointerDown: (_) => areasManager.activeArea = widget.viewArea,
      child: child,
    );
  }

  Widget makeFilesStack(BuildContext context) {
    return IndexedStack(
      index: widget.viewArea.indexOf(widget.viewArea.currentFile!),
      children: widget.viewArea.map((file) => 
        ConstrainedBox(
          key: Key(file.uuid),
          constraints: const BoxConstraints.expand(),
          child: FocusScope(
            child: makeFileEditor(file),
          ),
        )
      ).toList(),
    );
  }

  Widget makeEmptyTab(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints.loose(const Size(150, 150)),
        child: Opacity(
          opacity: 0.25,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 250),
            turns: Random().nextInt(100) == 69 ? 1 : 0,
            child: AnimatedScale(
              scale: isDroppingFile ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: const _BezierCurve(0, 1.5, 1.2, 1),
              child: Image(
                image: AssetImage(getTheme(context).editorIconPath!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget makeTabBar() {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      child: SizedBox(
        height: 30,
        child: Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent)
              return;
            PointerScrollEvent scrollEvent = event;
            var delta = scrollEvent.scrollDelta.dy != 0 ? scrollEvent.scrollDelta.dy : scrollEvent.scrollDelta.dx;
            var newOffset = tabBarScrollController.offset + delta;
            newOffset = clamp(newOffset, 0, tabBarScrollController.position.maxScrollExtent);
            tabBarScrollController.jumpTo(
              newOffset,
              // duration: const Duration(milliseconds: 3000 ~/ 60),
              // curve: Curves.linear
            );
          },
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.transparent,
            ),
            child: ReorderableListView(
              scrollController: tabBarScrollController,
              scrollDirection: Axis.horizontal,
              onReorder: (int oldIndex, int newIndex) {
                if (newIndex - 1 > oldIndex)
                  newIndex--;
                if (oldIndex < 0 || oldIndex >= widget.viewArea.length || newIndex < 0 || newIndex >= widget.viewArea.length) {
                  print("Invalid reorder: $oldIndex -> $newIndex (length: ${widget.viewArea.length})");
                  return;
                }
                widget.viewArea.move(oldIndex, newIndex);
              },
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              children: widget.viewArea
                .map((file) => ReorderableDragStartListener(
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
        ),
      ),
    );
  }

  Widget makeDropIndicator() {
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

class _BezierCurve extends Curve {
  final double a;
  final double b;
  final double c;
  final double d;

  const _BezierCurve(this.a, this.b, this.c, this.d);

  @override
  double transformInternal(double x) {
    return a*pow((1-x), 3) + 3*b*pow((1-x), 2)*x + 3*c*(1-x)*pow(x, 2) + d*pow(x, 3);
  }
}
