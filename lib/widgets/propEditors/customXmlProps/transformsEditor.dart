

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../simpleProps/optionalPropEditor.dart';
import '../simpleProps/propEditorFactory.dart';

class TransformsEditor extends ChangeNotifierWidget {
  final XmlProp parent;
  final bool canBeScaled;
  
  TransformsEditor({super.key, required this.parent, this.canBeScaled = true})
    : super(notifiers: [
      parent,
      if (parent.get("location") != null)
        parent.get("location")!,
    ]);

  @override
  State<TransformsEditor> createState() => _TransformsEditorState();
}

final _positionHash = crc32("position");
final _rotationHash = crc32("rotation");
final _scaleHash = crc32("scale");

class _TransformsEditorState extends ChangeNotifierState<TransformsEditor> {
  void addProp(int tagId, XmlProp parent, double initValue, int Function() getInsertPos) {
    parent.insert(
      getInsertPos(),
      XmlProp(
        file: widget.parent.file,
        tagId: tagId,
        value: VectorProp(List.filled(3, initValue)),
      )
    );
  }

  int getPosInsertPos() => 0;

  int getRotInsertPos() {
    bool hasLocation = widget.parent.any((prop) => prop.tagName == "location");
    if (hasLocation) {
      return widget.parent.isNotEmpty ? 1 : 0;
    }
    int posI = widget.parent.indexWhere((prop) => prop.tagName == "position");
    return posI + 1;
  }

  int getScaleInsertPos() {
    bool hasLocation = widget.parent.any((prop) => prop.tagName == "location");
    if (hasLocation) {
      int locI = widget.parent.indexWhere((prop) => prop.tagName == "location");
      return locI + 1;
    }
    int rotI = widget.parent.indexWhere((prop) => prop.tagName == "rotation");
    if (rotI != -1)
      return rotI + 1;
    int posI = widget.parent.indexWhere((prop) => prop.tagName == "position");
    return posI + 1;
  }

  @override
  Widget build(BuildContext context) {
    var location = widget.parent.get("location");
    bool hasLocation = location != null;
    var position = hasLocation ? widget.parent.get("location")!.get("position") : widget.parent.get("position");
    var rotation = hasLocation ? widget.parent.get("location")!.get("rotation") : widget.parent.get("rotation");
    var scale = widget.parent.get("scale");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        makeIconRow(
          icon: Transform.rotate(
            angle: -pi / 4,
            child: Icon(Icons.zoom_out_map, size: 18)
          ),
          child: position == null
            ? OptionalPropEditor(
            onAdd: () => addProp(_positionHash, hasLocation ? widget.parent.get("location")! : widget.parent, 0, getPosInsertPos),
            prop: position,
            parent: location ?? widget.parent,
          )
            : Row(
              children: [
                Flexible(child: makePropEditor(position.value)),
                SizedBox(width: 30),
              ],
            ),
        ),
        makeIconRow(
          icon: Icon(Icons.flip_camera_android, size: 18),
          child: OptionalPropEditor(
            onAdd: () => addProp(_rotationHash, hasLocation ? widget.parent.get("location")! : widget.parent, 0, getRotInsertPos),
            prop: rotation,
            parent: location ?? widget.parent,
          ),
        ),
        if (widget.canBeScaled)
          makeIconRow(
            icon: Icon(Icons.open_in_full, size: 18),
            child: OptionalPropEditor(
              onAdd: () => addProp(_scaleHash, widget.parent, 1, getScaleInsertPos),
              prop: scale,
              parent: widget.parent,
            ),
          ),
      ],
    );
  }

  Widget makeIconRow({ required Widget icon, required Widget child }) {
    return Row(
      children: [
        icon,
        SizedBox(width: 10),
        Flexible(child: child),
      ],
    );
  }
}
