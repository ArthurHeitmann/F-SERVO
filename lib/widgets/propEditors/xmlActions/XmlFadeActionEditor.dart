
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import 'XmlActionEditor.dart';
import 'XmlActionInnerEditor.dart';

class FadeActionInnerEditor extends XmlActionInnerEditor {
  FadeActionInnerEditor({ super.key, required super.action, required super.showDetails });

  @override
  State<FadeActionInnerEditor> createState() => _FadeActionInnerEditorState();
}

class _FadeActionInnerEditorState extends XmlActionInnerEditorState<FadeActionInnerEditor> {
  @override
  Widget build(BuildContext context) {
    return NestedContextMenu(
      buttons: [
        optionalPropButtonConfig(widget.action, "param", () => 4, _makeParam),
        optionalValPropButtonConfig(
          widget.action, "time", () => getNextInsertIndexAfter(widget.action, ["param", "attribute"]),
          () => NumberProp(2.0, false)
        ),
        optionalValPropButtonConfig(
          widget.action, "hack_whiteFade", () => getNextInsertIndexAfter(widget.action, ["type"]),
          () => NumberProp(1, true)
        ),
      ],
      child: Column(
        children: widget.action
          .where((e) => widget.showDetails || !ignoreTagNames.contains(e.tagName))
          .map((e) => makeXmlPropEditor(e, widget.showDetails))
          .toList(),
      ),
    );
  }

  List<XmlProp> _makeParam() {
    return [
      makeXmlElement(name: "color", text: "1"),
      makeXmlElement(name: "speed", text: "0"),
      makeXmlElement(name: "type", text: "0"),
      makeXmlElement(name: "bNoFade", text: "0"),
    ]
      .map((e) => XmlProp.fromXml(
        e,
        file: widget.action.file,
        parentTags: widget.action.nextParents(),
      ))
      .toList();
  }
}
