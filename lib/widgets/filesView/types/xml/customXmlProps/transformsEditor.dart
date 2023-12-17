

import 'dart:math';

import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../../../../stateManagement/Property.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../../../utils/utils.dart';
import '../../../../misc/ChangeNotifierWidget.dart';
import '../../../../misc/nestedContextMenu.dart';
import '../../../../propEditors/propEditorFactory.dart';
import '../../../../propEditors/propTextField.dart';
import '../XmlPropEditorFactory.dart';
import 'optionalPropEditor.dart';

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
  XmlProp addProp(int tagId, XmlProp parent, double initValue, int Function() getInsertPos) {
    var newProp = XmlProp(
      file: widget.parent.file,
      tagId: tagId,
      value: VectorProp(List.filled(3, initValue), fileId: widget.parent.file),
      parentTags: parent.nextParents(),
    );
    parent.insert(getInsertPos(), newProp);
    return newProp;
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
    return NestedContextMenu(
      buttons: [
        ContextMenuButtonConfig(
          "Copy Transforms",
          icon: const Icon(Icons.copy, size: 14),
          onPressed: () => onCopyTransforms(position, rotation, scale),
        ),
        ContextMenuButtonConfig(
          "Paste Transforms",
          icon: const Icon(Icons.paste, size: 14),
          onPressed: () => onPasteTransforms(position, rotation, scale)
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          makeIconRow(
            icon: Transform.rotate(
              angle: -pi / 4,
              child: const Icon(Icons.zoom_out_map, size: 18)
            ),
            onAdd: addPositionProp,
            prop: position,
            parent: location ?? widget.parent,
            canBeRemoved: position == null && widget.itemsCanBeRemoved,
          ),
          if (widget.canBeRotated)
            makeIconRow(
              icon: const Icon(Icons.flip_camera_android, size: 18),
              onAdd: addRotationProp,
              prop: rotation,
              parent: location ?? widget.parent,
              canBeRemoved: widget.itemsCanBeRemoved,
            ),
          if (widget.canBeScaled)
            makeIconRow(
              icon: const Icon(Icons.open_in_full, size: 18),
              onAdd: addScaleProp,
              prop: scale,
              parent: widget.parent,
              canBeRemoved: widget.itemsCanBeRemoved,
            ),
          if (hasLocation)
            ...makeXmlMultiPropEditor(location, true, (prop) => !_defaultLocationTagNames.contains(prop.tagName),)
        ],
      ),
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
            const SizedBox(width: 30),
        ],
      );
    return Row(
      children: [
        icon,
        const SizedBox(width: 10),
        Flexible(child: editor),
      ],
    );
  }

  XmlProp addPositionProp() {
    var location = widget.parent.get("location");
    bool hasLocation = location != null;
    return addProp(_positionHash, hasLocation ? widget.parent.get("location")! : widget.parent, 0, getPosInsertPos);
  }

  XmlProp addRotationProp() {
    var location = widget.parent.get("location");
    bool hasLocation = location != null;
    return addProp(_rotationHash, hasLocation ? widget.parent.get("location")! : widget.parent, 0, getRotInsertPos);
  }

  XmlProp addScaleProp() {
    return addProp(_scaleHash, widget.parent, 1, getScaleInsertPos);
  }

  void onCopyTransforms(XmlProp? pos, XmlProp? rot, XmlProp? scale) {
    var xmlElements = [
      if (pos != null)
        XmlElement(XmlName("position"), [], [XmlText(pos.value.toString())]),
      if (rot != null)
        XmlElement(XmlName("rotation"), [], [XmlText(rot.value.toString())]),
      if (scale != null)
        XmlElement(XmlName("scale"), [], [XmlText(scale.value.toString())]),
    ];
    var xml = XmlDocument([
      XmlElement(XmlName("transforms"), [], xmlElements)
    ]);
    copyToClipboard(xml.toXmlString(pretty: true, indent: "\t"));
  }

  void onPasteTransforms(XmlProp? pos, XmlProp? rot, XmlProp? scale) async {
    var clipboard = await getClipboardText();
    if (clipboard == null) {
      showToast("Clipboard is empty");
      return;
    }
    var xml = XmlDocument.parse(clipboard);
    var transforms = xml.rootElement;
    if (transforms.name.local != "transforms") {
      showToast("Clipboard does not contain transforms");
      return;
    }
    bool hasPos = false;
    bool hasRot = false;
    bool hasScale = false;
    for (var transform in transforms.children) {
      if (transform is! XmlElement)
        continue;
      var transformText = transform.innerText;
      XmlProp? prop;
      switch (transform.name.local) {
        case "position":
          hasPos = true;
          if (pos == null)
            prop = addPositionProp();
          else
            prop = pos;
          break;
        case "rotation":
          hasRot = true;
          if (rot == null)
            prop = addRotationProp();
          else
            prop = rot;
          break;
        case "scale":
          hasScale = true;
          if (scale == null)
            prop = addScaleProp();
          else
            prop = scale;
          break;
      }
      if (prop == null)
        continue;
      prop.value.updateWith(transformText);
    }
    if (!hasPos && pos != null)
      pos.value.updateWith("0 0 0");
    if (!hasRot && rot != null)
      rot.value.updateWith("0 0 0");
    if (!hasScale && scale != null)
      scale.value.updateWith("1 1 1");
  }
}

const _defaultLocationTagNames = ["position", "rotation"];
