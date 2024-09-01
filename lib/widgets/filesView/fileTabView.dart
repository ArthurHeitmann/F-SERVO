import 'dart:io';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../stateManagement/openFiles/filesAreaManager.dart';
import '../../stateManagement/openFiles/openFileTypes.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../utils/utils.dart';
import '../../widgets/theme/customTheme.dart';
import '../misc/ChangeNotifierWidget.dart';
import 'FileTabEntry.dart';
import 'FileType.dart';


class FileTabView extends ChangeNotifierWidget {
  final FilesAreaManager viewArea;
  
  FileTabView(this.viewArea, {super.key}) :
    super(notifiers: [viewArea.files, viewArea.currentFile]);

  @override
  State<FileTabView> createState() => _FileTabViewState();
}

class _FileTabViewState extends ChangeNotifierState<FileTabView> {
  ScrollController tabBarScrollController = ScrollController();
  String? prevActiveUuid;
  bool isDroppingFile = false;

  @override
  void onNotified() {
    var newActiveUuid = widget.viewArea.currentFile.value?.uuid;
    if (prevActiveUuid != newActiveUuid && newActiveUuid != null)
      scrollTabIntoView(newActiveUuid);
    prevActiveUuid = newActiveUuid;

    super.onNotified();
  }

  @override
  void dispose() {
    tabBarScrollController.dispose();
    super.dispose();
  }

  void scrollTabIntoView(String uuid) {
    const tabWidth = 200.0;
    var viewWidth = (context.findRenderObject() as RenderBox).size.width;
    
    var fileData = widget.viewArea.files.firstWhere((f) => f.uuid == uuid);
    var index = widget.viewArea.files.indexOf(fileData);
    var tabPos = max(0.0, index * tabWidth - 15);
    var tabEnd = tabPos + tabWidth + 30;

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
    int openedFiles = 0;
    const fileExplorerExtensions = { ".pak", ...datExtensions, ".yax", ".bin", ".wai", ".wsp", ...bxmExtensions, ".bnk", ".cpk" };
    for (var file in files) {
      bool isSaveSlotData = file.name.startsWith("SlotData_") && file.name.endsWith(".dat");
      if (fileExplorerExtensions.contains(path.extension(file.name)) && !isSaveSlotData || await Directory(file.path).exists()) {
        var entry = await openHierarchyManager.openFile(file.path);
        if (entry?.isOpenable == true)
          entry!.onOpen();
        if (entry != null)
          openedFiles++;
        continue;
      }
      var newFileData = areasManager.openFile(file.path, toArea: widget.viewArea);
      openedFiles++;
      firstFile ??= newFileData;
    }
    if (firstFile != null)
      widget.viewArea.setCurrentFile(firstFile);
    windowManager.focus();
    setState(() {});

    messageLog.add("Opened ${pluralStr(openedFiles, "file")}");
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: ModalRoute.of(context)!.isCurrent,
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
              child: widget.viewArea.currentFile.value != null
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
      onPointerDown: (_) => areasManager.setActiveArea(widget.viewArea),
      child: child,
    );
  }

  Widget makeFilesStack(BuildContext context) {
    return IndexedStack(
      index: widget.viewArea.files.indexOf(widget.viewArea.currentFile.value!),
      children: widget.viewArea.files.map((file) =>
        ConstrainedBox(
          key: Key(file.uuid),
          constraints: const BoxConstraints.expand(),
          child: FocusTraversalGroup(
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
      top: -1,
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
                if (oldIndex < 0 || oldIndex >= widget.viewArea.files.length || newIndex < 0 || newIndex >= widget.viewArea.files.length) {
                  print("Invalid reorder: $oldIndex -> $newIndex (length: ${widget.viewArea.files.length})");
                  return;
                }
                widget.viewArea.moveFile(oldIndex, newIndex);
              },
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              children: widget.viewArea.files
                .map((file) => ReorderableDragStartListener(
                  key: Key(file.uuid),
                  index: widget.viewArea.files.indexOf(file),
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
