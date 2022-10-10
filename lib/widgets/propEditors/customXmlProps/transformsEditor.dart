

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/optionalPropEditor.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';

class TransformsEditor<T extends PropTextField> extends ChangeNotifierWidget {
  final XmlProp parent;
  final bool canBeRotated;
  final bool canBeScaled;
  final bool itemsCanBeRemoved;
  
  TransformsEditor({super.key, required this.parent, this.canBeRotated = true, this.canBeScaled = true, this.itemsCanBeRemoved = true})
    : super(notifiers: [
      parent,
      if (parent.get("location") != null)
        parent.get("location")!,
    ]);

  @override
  State<TransformsEditor> createState() => _TransformsEditorState<T>();
}

final _positionHash = crc32("position");
final _rotationHash = crc32("rotation");
final _scaleHash = crc32("scale");

class _TransformsEditorState<T extends PropTextField> extends ChangeNotifierState<TransformsEditor> {
  void addProp(int tagId, XmlProp parent, double initValue, int Function() getInsertPos) {
    parent.insert(
      getInsertPos(),
      XmlProp(
        file: widget.parent.file,
        tagId: tagId,
        value: VectorProp(List.filled(3, initValue)),
        parentTags: parent.nextParents(),
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
          onAdd: () => addProp(_positionHash, hasLocation ? widget.parent.get("location")! : widget.parent, 0, getPosInsertPos),
          prop: position,
          parent: location ?? widget.parent,
          canBeRemoved: position == null && widget.itemsCanBeRemoved,
        ),
        if (widget.canBeRotated)
          makeIconRow(
            icon: Icon(Icons.flip_camera_android, size: 18),
            onAdd: () => addProp(_rotationHash, hasLocation ? widget.parent.get("location")! : widget.parent, 0, getRotInsertPos),
            prop: rotation,
            parent: location ?? widget.parent,
            canBeRemoved: widget.itemsCanBeRemoved,
          ),
        if (widget.canBeScaled)
          makeIconRow(
            icon: Icon(Icons.open_in_full, size: 18),
            onAdd: () => addProp(_scaleHash, widget.parent, 1, getScaleInsertPos),
            prop: scale,
            parent: widget.parent,
            canBeRemoved: widget.itemsCanBeRemoved,
          ),
        if (hasLocation)
          ...makeXmlMultiPropEditor(location, true, (prop) => !_defaultLocationTagNames.contains(prop.tagName),)
      ],
    );
  }

  Widget makeIconRow({ required Widget icon, required void Function() onAdd, required XmlProp? prop, required XmlProp parent, required bool canBeRemoved }) {
    var editor = canBeRemoved
      ? OptionalPropEditor<T>(
        onAdd: onAdd,
        prop: prop,
        parent: parent,
      )
      : Row(
        children: [
          Flexible(child: makePropEditor<T>(prop!.value)),
          if (widget.itemsCanBeRemoved)
            SizedBox(width: 30),
        ],
      );
    return Row(
      children: [
        icon,
        SizedBox(width: 10),
        Flexible(child: editor),
      ],
    );
  }
}

const _defaultLocationTagNames = ["position", "rotation"];
