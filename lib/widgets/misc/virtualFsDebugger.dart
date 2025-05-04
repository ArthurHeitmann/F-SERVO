
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../fileSystem/FileSystem.dart';
import '../../fileSystem/VirtualEntities.dart';
import '../theme/customTheme.dart';
import 'ChangeNotifierWidget.dart';
import 'SmoothScrollBuilder.dart';
import 'onHoverBuilder.dart';

class VirtualFsDebugger extends StatefulWidget {
  const VirtualFsDebugger({super.key});

  @override
  State<VirtualFsDebugger> createState() => _VirtualFsDebuggerState();
}

class _VirtualFsDebuggerState extends State<VirtualFsDebugger> {
  bool show = false;
  ValueNotifier<String?> selectedPath = ValueNotifier(null);
  int uniqueId = 0;

  @override
  Widget build(BuildContext context) {
    if (!show) {
      return TextButton(
        child: Text("Show Virtual File System Debugger"),
        onPressed: () => setState(() => show = true),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 600,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmoothSingleChildScrollView(
            child: _EntityEntry(
              key: ValueKey(uniqueId),
              entity: FS.i.virtualRoot,
              selectedPath: selectedPath,
              expand: true,
            ),
          ),
          VerticalDivider(),
          _FileViewer(
            path: selectedPath,
          ),
        ],
      ),
    );
  }
}

class _EntityEntry extends ChangeNotifierWidget {
  final VirtualEntity entity;
  final ValueNotifier<String?> selectedPath;
  final bool expand;
  final int indent;

  _EntityEntry({
    super.key,
    required this.entity,
    required this.selectedPath,
    this.expand = false,
    this.indent = 0,
  }) : super(notifier: selectedPath);

  @override
  State<_EntityEntry> createState() => __EntityEntryState();
}

class __EntityEntryState extends ChangeNotifierState<_EntityEntry> {
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    expanded = widget.expand;
  }

  bool get isSelected => widget.selectedPath.value == widget.entity.path;

  @override
  Widget build(BuildContext context) {
    var isFolder = widget.entity is VirtualFolder;
    var isFile = widget.entity is VirtualFile;
    var folder = isFolder ? widget.entity as VirtualFolder : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnHoverBuilder(
          builder: (context, isHovered) {
            Color color;
            var textColor = getTheme(context).textColor!;
            if (isFile && isSelected)
              color = textColor.withValues(alpha: 0.2);
            else if (isHovered)
              color = textColor.withValues(alpha: 0.1);
            else
              color = Colors.transparent;
            return GestureDetector(
              onTap: () {
                if (isFolder) {
                  setState(() => expanded = !expanded);
                } else if (isFile) {
                  if (isSelected) {
                    widget.selectedPath.value = null;
                  } else {
                    widget.selectedPath.value = widget.entity.path;
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: color,
                height: 25,
                padding: EdgeInsets.only(left: widget.indent * 10),
                child: Row(
                  children: [
                    if (isFolder)
                      Icon(expanded ? Icons.arrow_drop_down : Icons.arrow_right, size: 18),
                    Icon(
                      isFolder ? Icons.folder : Icons.insert_drive_file,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(widget.entity.name),
                  ],
                ),
              ),
            );
          }
        ),
        if (folder != null && expanded)
          for (var child in folder.children)
            _EntityEntry(
              key: ValueKey(child.path),
              entity: child,
              selectedPath: widget.selectedPath,
              expand: widget.selectedPath.value == child.path,
              indent: widget.indent + 1,
            ),
      ],
    );
  }
}

class _FileViewer extends ChangeNotifierWidget {
  final ValueNotifier<String?> path;

   _FileViewer({
    required this.path,
  }) : super(notifier: path);

  @override
  State<_FileViewer> createState() => __FileViewerState();
}

class __FileViewerState extends ChangeNotifierState<_FileViewer> {
  String? lastPath;
  Uint8List? bytes;

  @override
  void initState() {
    super.initState();
    loadFile();
  }

  void loadFile() async {
    if (lastPath == widget.path.value)
      return;
    lastPath = widget.path.value;
    if (lastPath == null || !await FS.i.existsFile(lastPath!)) {
      bytes = null;
      setState(() {});
      return;
    }
    bytes = await FS.i.read(lastPath!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    loadFile();
    if (bytes == null) {
      return SizedBox.shrink();
    }
    int bytesPerLine = 16;
    int lines = (bytes!.lengthInBytes / bytesPerLine).ceil();
    return SizedBox(
      width: 450,
      child: ListView.builder(
        itemCount: lines,
        itemExtent: 20,
        itemBuilder: (context, index) {
          int start = index * bytesPerLine;
          int end = (index + 1) * bytesPerLine;
          if (end > bytes!.lengthInBytes)
            end = bytes!.lengthInBytes;
          var line = bytes!.sublist(start, end);
          var hexStr = line.map((e) => e.toRadixString(16).padLeft(2, "0")).join(" ");
          var asciiStr = line.map((e) {
            if (e >= 32 && e <= 126) {
              return String.fromCharCode(e);
            } else {
              return ".";
            }
          }).join("");
          var style = TextStyle(fontSize: 10);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${start.toRadixString(16).padLeft(4, "0")}:".padRight(7), style: style,),
              Text(hexStr, overflow: TextOverflow.ellipsis, style: style,),
              SizedBox(width: 10),
              Text(asciiStr, overflow: TextOverflow.ellipsis, style: style,),
            ],
          );
        },
      ),
    );
  }
}
