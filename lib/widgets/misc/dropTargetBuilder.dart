
import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../fileSystem/FileSystem.dart';
import '../../fileSystem/VirtualFileSystem.dart';
import 'indexedStackIsVisible.dart';

class DropTargetBuilder extends StatefulWidget {
  final void Function(List<String> paths) onDrop;
  final Widget Function(BuildContext context, bool isDropping) builder;

  const DropTargetBuilder({super.key, required this.onDrop, required this.builder});

  @override
  State<DropTargetBuilder> createState() => _DropTargetBuilderState();
}

class _DropTargetBuilderState extends State<DropTargetBuilder> {
  static int _dropping = 0;

  bool isDropping = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: ModalRoute.of(context)!.isCurrent && IndexedStackIsVisible.of(context) != false,
      onDragEntered: (_) {
        _dropping += 1;
        isDropping = true;
        setState(() {});
      },
      onDragExited: (_) {
        _dropping = max(0, _dropping - 1);
        isDropping = false;
        setState(() {});
      },
      onDragDone: (details) async {
        if (_dropping > 0)
          return;
        List<String> paths;
        if (FS.i.needsVirtualFs) {
          paths = details.files.map((f) => "\$opened${VirtualFileSystem.separator}${f.name}").toList();
          for (var (i, file) in details.files.indexed)
            FS.i.registerFile(paths[i], await file.readAsBytes());
        }
        else {
          paths = details.files.map((f) => f.path).toList();
        }
        widget.onDrop(paths);
      },
      child: widget.builder(context, isDropping),
    );
  }
}
