

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/CustomIcons.dart';
import '../../misc/selectionPopup.dart';
import '../customXmlProps/areaEditor.dart';
import '../customXmlProps/commandEditor.dart';
import '../customXmlProps/conditionEditor.dart';
import '../customXmlProps/curveEditor.dart';
import '../customXmlProps/entityEditor.dart';
import '../customXmlProps/layoutsEditor.dart';
import '../customXmlProps/paramEditor.dart';
import '../customXmlProps/puidReferenceEditor.dart';
import '../customXmlProps/scriptVariableEditor.dart';
import '../customXmlProps/transformsEditor.dart';
import '../xmlActions/xmlArrayEditor.dart';
import 'XmlPropEditor.dart';
import 'propTextField.dart';

class XmlPresetContext {
  XmlProp parent;

  XmlPresetContext({required this.parent});

  OpenFileData? get file => parent.file;
  List<String> get parentTags => parent.nextParents();
  String? get parentName => parent.tagName;
}

class XmlRawPreset {
  final Widget Function<T extends PropTextField>(XmlProp prop, bool showDetails) editor;
  final FutureOr<XmlProp?> Function(XmlPresetContext cxt) propFactory;

  const XmlRawPreset(this.editor, this.propFactory);

  XmlPreset withCxt(XmlPresetContext context) =>
    XmlPreset(editor, propFactory, context);

  XmlPreset withCxtV(XmlProp parent) =>
    XmlPreset(editor, propFactory, XmlPresetContext(parent: parent));
}

class XmlPreset extends XmlRawPreset {
  final XmlPresetContext? _context;

  const XmlPreset(super.editor, super.propFactory, this._context);

  FutureOr<XmlProp?> prop() => _context != null ? propFactory(_context!) : null;  
}

class XmlPresets {
  static XmlRawPreset area = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => AreaEditor(prop: prop, showDetails: showDetails),
    (cxt) {
      return showSelectionPopup(getGlobalContext(), [
        SelectionPopupConfig(icon: CustomIcons.cube, name: "Box", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "code", text: "0x${crc32("app::area::BoxArea").toRadixString(16)}"),
              makeXmlElement(name: "position", text: "0 0 0"),
              makeXmlElement(name: "rotation", text: "0 0 0"),
              makeXmlElement(name: "scale", text: "1 1 1"),
              makeXmlElement(name: "points", text: "-1 -1 1 -1 1 1 -1 1"),
              makeXmlElement(name: "height", text: "1"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
        SelectionPopupConfig(icon: CustomIcons.cylinder, name: "Cylinder", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "code", text: "0x${crc32("app::area::CylinderArea").toRadixString(16)}"),
              makeXmlElement(name: "position", text: "0 0 0"),
              makeXmlElement(name: "rotation", text: "0 0 0"),
              makeXmlElement(name: "scale", text: "1 1 1"),
              makeXmlElement(name: "radius", text: "1"),
              makeXmlElement(name: "height", text: "1"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
        SelectionPopupConfig(icon: CustomIcons.sphere, name: "Sphere", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "code", text: "0x${crc32("app::area::SphereArea").toRadixString(16)}"),
              makeXmlElement(name: "position", text: "0 0 0"),
              makeXmlElement(name: "radius", text: "1"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
      ]);
    },
  );
  static XmlRawPreset entity = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => EntityEditor(prop: prop, showDetails: showDetails),
    (cxt) {
      if (cxt.parentName == "layouts") {
        return XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
              makeXmlElement(name: "location", children: [
                makeXmlElement(name: "position", text: "0 0 0"),
                makeXmlElement(name: "rotation", text: "0 0 0"),
              ]),
              makeXmlElement(name: "objId", text: "em0000"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        );
      }
      if (cxt.parentName == "items") {
        return XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "objId", text: "em0000"),
              makeXmlElement(name: "rate", text: "0"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        );
      }
      throw Exception("Unsupported entity");
    },
  );
  static XmlRawPreset layouts = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => LayoutsEditor(prop: prop, showDetails: showDetails),
    (cxt) => null,
  );
  static XmlRawPreset params = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => ParamsEditor(prop: prop, showDetails: showDetails),
    (cxt) => showSelectionPopup(getGlobalContext(), [
        SelectionPopupConfig(name: "Default", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "name", text: "paramName"),
              makeXmlElement(name: "code", text: "0x${crc32("type").toRadixString(16)}"),
              makeXmlElement(name: "body", text: "value"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
        SelectionPopupConfig(name: "Level (Lv)", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "name", text: "Lv"),
              makeXmlElement(name: "code", text: "0x${crc32("int").toRadixString(16)}"),
              makeXmlElement(name: "body", text: "20"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
        SelectionPopupConfig(name: "Level Route B (Lv_B)", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "name", text: "Lv_B"),
              makeXmlElement(name: "code", text: "0x${crc32("int").toRadixString(16)}"),
              makeXmlElement(name: "body", text: "30"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
        SelectionPopupConfig(name: "Level Route C (Lv_C)", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "name", text: "Lv_C"),
              makeXmlElement(name: "code", text: "0x${crc32("int").toRadixString(16)}"),
              makeXmlElement(name: "body", text: "40"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
        SelectionPopupConfig(name: "NameTag", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "name", text: "NameTag"),
              makeXmlElement(name: "code", text: "0x${crc32("sys::String").toRadixString(16)}"),
              makeXmlElement(name: "body", text: "name"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
        SelectionPopupConfig(name: "ItemTable", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "name", text: "ItemTable"),
              makeXmlElement(name: "code", text: "0x${crc32("unsigned int").toRadixString(16)}"),
              makeXmlElement(name: "body", text: "0x0"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
        SelectionPopupConfig(name: "codeName", getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "name", text: "codeName"),
              makeXmlElement(name: "code", text: "0x${crc32("sys::String").toRadixString(16)}"),
              makeXmlElement(name: "body", text: "ft_XX"),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        )),
    ]));
  static XmlRawPreset condition = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => ConditionEditor(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(
        name: "value",
        children: [
          makeXmlElement(name: "puid",
            children: [
              makeXmlElement(name: "code", text: "0x0"),
              makeXmlElement(name: "id", text: "0x0"),
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
      ),
      file: cxt.file,
      parentTags: cxt.parentTags
    ),
  );
  static XmlRawPreset transforms = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => TransformsEditor(parent: prop),
    (cxt) => null,
  );
  static XmlRawPreset puidReference = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => PuidReferenceEditor(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "puid",
        children: [
          makeXmlElement(name: "code", text: "0x0"),
          makeXmlElement(name: "id", text: "0x0"),
        ],
      ),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset command = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => CommandEditor(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "value",
        children: [
          makeXmlElement(name: "puid", children: [
            makeXmlElement(name: "code", text: "0x0"),
            makeXmlElement(name: "id", text: "0x0"),
          ]),
          makeXmlElement(name: "command", children: [ // TODO SendCommand vs SendCommands
            makeXmlElement(name: "label", text: "commandLabel"),
          ]),
        ]
      ),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset codeAndId = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => XmlPropEditor<T>(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "value",
        children: [
          makeXmlElement(name: "code", text: "0x0"),
          makeXmlElement(name: "id", text: "0x0"),
        ],
      ),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset variable = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => ScriptVariableEditor<T>(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "value",
        children: [
          makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
          makeXmlElement(name: "name", text: "myVariable"),
          makeXmlElement(name: "value", children: [
            makeXmlElement(name: "code", text: "0x0"),
            makeXmlElement(name: "value", text: "0x0"),
          ]),
        ],
      ),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );

  static XmlRawPreset curve = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => CurveEditor(prop: prop, showDetails: showDetails),
    (cxt) => null,
  );

  static XmlRawPreset fallback = XmlRawPreset(
    <T extends PropTextField>(prop, showDetails) => XmlPropEditor<T>(prop: prop, showDetails: showDetails),
    (cxt) {
      if (cxt.parent.length < 2)
        return null;
      var example = cxt.parent[1];
      var copy = XmlProp.fromXml(
        example.toXml(),
        file: cxt.file,
        parentTags: example.parentTags
      );
      _resetProps(copy);
      return copy;
    },
  );
}


XmlRawPreset getXmlPropPreset(XmlProp prop) {
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
  // command
  if (prop.get("puid") != null && prop.get("command") != null) {
    return XmlPresets.command;
  }
  // variable
  if (prop.length == 3 && prop[0].tagName == "id" && prop[1].tagName == "name" && prop[2].tagName == "value") {
    return XmlPresets.variable;
  }
  // curve
  if (prop.get("controls") != null && prop.get("nodes") != null) {
    return XmlPresets.curve;
  }
  // fallback
  return XmlPresets.fallback;
}

List<Widget> makeXmlMultiPropEditor<T extends PropTextField>(
  XmlProp parent,
  bool showDetails, [
  bool Function(XmlProp)? filter,
]) {
  List<Widget> widgets = [];

  // <id><id> ... </id></id> shortcut
  if (parent.length == 1 && parent[0].length == 1 && parent[0].tagName == "id" && parent[0][0].tagName == "id") {
    return makeXmlMultiPropEditor(parent[0][0], showDetails, filter);
  }

  for (var i = 0; i < parent.length; i++) {
    var child = parent[i];
    var context = XmlPresetContext(parent: child);
    if (filter != null && !filter(child)) {
      continue;
    }
    if (_skipPropNames.contains(child.tagName)) {
      continue;
    }
    // transformable with position, rotation (optional), scale (optional)
    if (child.tagName == "location") {
      widgets.add(XmlPresets.transforms.withCxt(context).editor<T>(parent, showDetails));
      if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
        i++;
    }
    else if (child.tagName == "position") {
      widgets.add(XmlPresets.transforms.withCxt(context).editor<T>(parent, showDetails));
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
      widgets.add(XmlPresets.puidReference.withCxt(context).editor<T>(parent, showDetails));
      if (i + 1 < parent.length && _puidRefIdTags.contains(parent[i + 1].tagName))
        i++;
    }
    // command
    else if (child.tagName == "puid" && i + 1 < parent.length && (parent[i + 1].tagName == "command" || parent[i + 1].tagName == "hit" || parent[i + 1].tagName == "hitout")) {
      widgets.add(XmlPresets.command.withCxt(context).editor<T>(parent, showDetails));
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
      context = XmlPresetContext(parent: parent);
      var childProp = parent.where((child) => _arrayChildTags.contains(child.tagName));
      XmlRawPreset preset;
      String childTagName = _arrayChildTags.first;
      // determine array type from first child
      if (childProp.isNotEmpty) {
        var first = childProp.first;
        childTagName = first.tagName;
        preset = getXmlPropPreset(first);
      }
      // try to guess array type from parent tags
      else if (parent.tagName.toLowerCase().contains("area"))
        preset = XmlPresets.area;
      else if (parent.tagName == "layouts")
        preset = XmlPresets.entity;
      else if (parent.tagName == "param")
        preset = XmlPresets.params;
      else if (parent.tagName == "items") {
        if (parent.parentTags.last == "action") // works in 99.7% of cases (except with RandomCommandsArea :) )
          preset = XmlPresets.entity;
        else
          preset = XmlPresets.command;
      }
      else if (parent.tagName == "variables")
        preset = XmlPresets.variable;
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
      widgets.add(getXmlPropPreset(child).withCxt(context).editor<T>(child, showDetails));
    }
  }

  return widgets;
}

Widget makeXmlPropEditor<T extends PropTextField>(XmlProp prop, bool showDetails) {
  var context = XmlPresetContext(parent: prop);
  return getXmlPropPreset(prop).withCxt(context).editor<T>(prop, showDetails);
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

void _resetProp(Prop prop) {
  if (prop is HexProp)
    prop.value = 0;
  else if (prop is NumberProp)
    prop.value = 0;
  else if (prop is StringProp)
    prop.value = "str";
  else if (prop is VectorProp) {
    for (var p in prop)
      p.value = 0;
  }
}

void _resetProps(XmlProp prop) {
  _resetProp(prop.value);
  for (var child in prop)
    _resetProps(child);
}
