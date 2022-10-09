

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../customXmlProps/areaEditor.dart';
import '../customXmlProps/commandEditor.dart';
import '../customXmlProps/conditionEditor.dart';
import '../customXmlProps/entityEditor.dart';
import '../customXmlProps/layoutsEditor.dart';
import '../customXmlProps/paramEditor.dart';
import '../customXmlProps/puidReferenceEditor.dart';
import '../customXmlProps/transformsEditor.dart';
import '../xmlActions/XmlActionEditorFactory.dart';
import '../xmlActions/xmlArrayEditor.dart';
import 'XmlPropEditor.dart';
import 'propTextField.dart';

class XmlPresetInit {
  OpenFileData? file;
  String parentPropName;

  XmlPresetInit({required this.file, required this.parentPropName});
}

class XmlPreset {
  final Widget Function<T extends PropTextField>(XmlProp prop, bool showDetails) editor;
  final FutureOr<XmlProp?> Function(XmlPresetInit init) prop;

  XmlPreset(this.editor, this.prop);
}

class XmlPresets {
  static XmlPreset action = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => makeXmlActionEditor(action: prop as XmlActionProp, showDetails: showDetails),
    (init) => null,
  );

  static XmlPreset area = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => AreaEditor(prop: prop, showDetails: showDetails),
    (init) => null,
  );
  static XmlPreset entity = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => EntityEditor(prop: prop, showDetails: showDetails),
    (init) {
      if (init.parentPropName == "layouts") {
        return XmlProp.fromXml(makeXmlElement(
          name: "value",
          children: [
            makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
            makeXmlElement(name: "location", children: [
              makeXmlElement(name: "position", text: "0 0 0"),
              makeXmlElement(name: "rotation", text: "0 0 0"),
            ]),
            makeXmlElement(name: "objId", text: "em0000"),
          ]
        ));
      }
      if (init.parentPropName == "items") {
        return XmlProp.fromXml(makeXmlElement(
          name: "value",
          children: [
            makeXmlElement(name: "objId", text: "em0000"),
            makeXmlElement(name: "rate", text: "0"),
          ]
        ));
      }
      throw Exception("Unsupported entity");
    },
  );
  static XmlPreset layouts = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => LayoutsEditor(prop: prop, showDetails: showDetails),
    (init) => null,
  );
  static XmlPreset params = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => ParamsEditor(prop: prop, showDetails: showDetails),
    (init) => XmlProp.fromXml(makeXmlElement(
      name: "value",
      children: [
        makeXmlElement(name: "name", text: "paramName"),
        makeXmlElement(name: "code", text: "0x${crc32("type").toRadixString(16)}"),
        makeXmlElement(name: "body", text: "0"),
      ]
    ),
  ));
  static XmlPreset condition = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => ConditionEditor(prop: prop, showDetails: showDetails),
    (init) => XmlProp.fromXml(makeXmlElement(
      name: "value",
      children: [
        makeXmlElement(name: "puid",
          children: [
            makeXmlElement(name: "code", text: "0x0"),
            makeXmlElement(name: "id", text: ""),
          ],
        ),
        makeXmlElement(name: "condition",
          children: [
            makeXmlElement(name: "state", children: [
              makeXmlElement(name: "label", text: "conditionLabel"),
            ]),
            makeXmlElement(name: "pred", text: "0"),
          ],
        ),
      ]
    )),
  );
  static XmlPreset transforms = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => TransformsEditor(parent: prop),
    (init) => null,
  );
  static XmlPreset puidReference = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => PuidReferenceEditor(prop: prop, showDetails: showDetails),
    (init) => XmlProp.fromXml(
      makeXmlElement(name: "puid",
        children: [
          makeXmlElement(name: "code", text: "0x0"),
          makeXmlElement(name: "id", text: ""),
        ],
      ),
      file: init.file
    ),
  );
  static XmlPreset command = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => CommandEditor(prop: prop, showDetails: showDetails),
    (init) => null,
  );

  static XmlPreset fallback = XmlPreset(
    <T extends PropTextField>(prop, showDetails) => XmlPropEditor<T>(prop: prop, showDetails: showDetails),
    (init) => null,
  );
}


XmlPreset getXmlPropPreset(XmlProp prop) {
  // area editor
  if (prop.isNotEmpty && prop[0].tagName == "code" && prop[0].value is HexProp && _areaTypes.contains((prop[0].value as HexProp).value)) {
    return XmlPresets.area;
  }
  // entity editor
  if (prop.isNotEmpty && prop.get("objId") != null) {
    return XmlPresets.entity;
  }
  // entity layouts
  if (prop.tagName == "layouts" && prop.get("normal")?.get("layouts") != null) {
    return XmlPresets.layouts;
  }
  // param
  if (prop.length == 3 && prop[0].tagName == "name" && prop[1].tagName == "code" && prop[2].tagName == "body") {
    return XmlPresets.params;
  }
  // condition
  if (prop.get("puid") != null && prop.get("condition") != null) {
    return XmlPresets.condition;
  }
  // fallback
  return XmlPresets.fallback;
}

List<Widget> makeXmlMultiPropEditor<T extends PropTextField>(
  XmlProp parent,
  bool showDetails, [
  bool Function(XmlProp)? filter,
  List<String> parentTagNames = const [],
]) {
  List<Widget> widgets = [];

  // <id><id> ... </id></id> shortcut
  if (parent.length == 1 && parent[0].length == 1 && parent[0].tagName == "id" && parent[0][0].tagName == "id") {
    return makeXmlMultiPropEditor(parent[0][0], showDetails, filter);
  }

  for (var i = 0; i < parent.length; i++) {
    var child = parent[i];
    if (filter != null && !filter(child)) {
      continue;
    }
    if (_skipPropNames.contains(child.tagName)) {
      continue;
    }
    // transformable with position, rotation (optional), scale (optional)
    if (child.tagName == "location") {
      widgets.add(XmlPresets.transforms.editor<T>(parent, showDetails));
      if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
        i++;
    }
    else if (child.tagName == "position") {
      widgets.add(XmlPresets.transforms.editor<T>(parent, showDetails));
      if (i + 1 < parent.length && parent[i + 1].tagName == "rotation") {
        i++;
        if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
          i++;
      }
      else if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
        i++;
    }
    // puid references
    else if (child.tagName == "code" && _puidRefCodes.contains((child.value as HexProp).value)) {
      widgets.add(XmlPresets.puidReference.editor<T>(parent, showDetails));
      if (i + 1 < parent.length && _puidRefIdTags.contains(parent[i + 1].tagName))
        i++;
    }
    // command
    else if (child.tagName == "puid" && i + 1 < parent.length && (parent[i + 1].tagName == "command" || parent[i + 1].tagName == "hit")) {
      widgets.add(XmlPresets.command.editor<T>(parent, showDetails));
      i++;
      if (i + 1 < parent.length && parent[i + 1].tagName == "hitout")
        i++;
      if (i + 1 < parent.length && parent[i + 1].tagName == "args")
        i++;
    }
    // array
    else if (_arrayLengthTags.contains(child.tagName) && (
      parent.toList().sublist(i + 1).every((child) => _arrayChildTags.contains(child.tagName)) ||
      i + 1 < parent.length && parent[i + 1].tagName == _arrayPostLengthSkipTag
        && parent.toList().sublist(i + 2).every((child) => _arrayChildTags.contains(child.tagName))
    )) {
      var childProp = parent.where((child) => _arrayChildTags.contains(child.tagName));
      XmlPreset preset;
      String childTagName = _arrayChildTags.first;
      if (childProp.isNotEmpty) {
        var first = childProp.first;
        childTagName = first.tagName;
        preset = getXmlPropPreset(first);
      }
      else if (parent.tagName.toLowerCase().contains("area"))
        preset = XmlPresets.area;
      else if (parent.tagName == "layouts")
        preset = XmlPresets.entity;
      else if (parent.tagName == "param")
        preset = XmlPresets.params;
      // TODO more based on parentTagNames
      else
        preset = XmlPresets.fallback;

      var linkIndex = parent.indexWhere((child) => child.tagName == _arrayPostLengthSkipTag);
      if (linkIndex != -1) {
        widgets.add(makeXmlPropEditor(parent[linkIndex], showDetails));
      }

      widgets.add(XmlArrayEditor(parent, preset, child, childTagName, showDetails));

      i = parent.length;
    }
    // fallback
    else {
      widgets.add(getXmlPropPreset(child).editor<T>(child, showDetails));
    }
  }

  return widgets;
}

Widget makeXmlPropEditor<T extends PropTextField>(XmlProp prop, bool showDetails) {
  return getXmlPropPreset(prop).editor<T>(prop, showDetails);
}

// for skipping
const _skipPropNames = [
  "bForwardState",
  "bDisable"
];

// areas
final _areaTypes = {
  crc32("app::area::BoxArea"),
  crc32("app::area::CylinderArea"),
  crc32("app::area::SphereArea"),
};

// puid references
final _puidRefCodes = {
  crc32("LayoutObj"),
  crc32("app::EntityLayout"),
  crc32("hap::Action"),
  crc32("hap::GroupImpl"),
  crc32("hap::Hap"),
  crc32("hap::SceneEntities"),
  crc32("hap::StateObject"),
};

const _puidRefIdTags = {
  "id",
  "value",
};

// arrays
const _arrayLengthTags = {
  "size",
  "count",
};

const _arrayChildTags = {
  "value",
  "child",
};

const _arrayPostLengthSkipTag = "link";
