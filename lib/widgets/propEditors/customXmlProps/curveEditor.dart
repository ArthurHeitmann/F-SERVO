

import 'package:flutter/material.dart';

import '../../misc/nestedContextMenu.dart';
import '../simpleProps/XmlPropEditor.dart';

class CurveEditor extends XmlPropEditor {
  CurveEditor({super.key, required super.prop, required super.showDetails, super.showTagName = true});

  @override
  State<XmlPropEditor> createState() => _CurveEditorState();
}

class _CurveEditorState extends XmlPropEditorState {
  @override
  Widget build(BuildContext context) {
    return NestedContextMenu(
      buttons: const [
        // ContextMenuButtonConfig(
        //   "Sync Curve to Blender",
        //   icon: const Icon(Icons.sync, size: 14,),
        //   onPressed: () => startSyncingObject(BezierSyncedObject(widget.prop))
        // ),
      ],
      child: super.build(context),
    );
  }
}
