
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'indexedStackIsVisible.dart';

class DropTargetBuilder extends StatefulWidget {
  final void Function(List<String> paths) onDrop;
  final Widget Function(BuildContext context, bool isDropping) builder;

  const DropTargetBuilder({super.key, required this.onDrop, required this.builder});

  @override
  State<DropTargetBuilder> createState() => _DropTargetBuilderState();
}

class _DropTargetBuilderState extends State<DropTargetBuilder> {
  bool isDropping = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: ModalRoute.of(context)!.isCurrent && IndexedStackIsVisible.of(context) != false,
      onDragEntered: (_) => setState(() => isDropping = true),
      onDragExited: (_) => setState(() => isDropping = false),
      onDragDone: (details) {
        widget.onDrop(details.files.map((f) => f.path).toList());
      },
      child: widget.builder(context, isDropping),
    );
  }
}
