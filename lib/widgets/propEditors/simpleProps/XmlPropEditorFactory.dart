

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../../main.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/paramPresets.dart';
import '../../../utils/puidPresets.dart';
import '../../../utils/utils.dart';
import '../../misc/CustomIcons.dart';
import '../../misc/selectionPopup.dart';
import '../customXmlProps/EmgPointEditor.dart';
import '../customXmlProps/EmgSpawnNodeEditor.dart';
import '../customXmlProps/areaEditor.dart';
import '../customXmlProps/commandEditor.dart';
import '../customXmlProps/conditionEditor.dart';
import '../customXmlProps/distEditor.dart';
import '../customXmlProps/entityEditor.dart';
import '../customXmlProps/layoutsEditor.dart';
import '../customXmlProps/minMaxPropEditor.dart';
import '../customXmlProps/paramEditor.dart';
import '../customXmlProps/puidReferenceEditor.dart';
import '../customXmlProps/scriptIdEditor.dart';
import '../customXmlProps/scriptVariableEditor.dart';
import '../customXmlProps/transformsEditor.dart';
import '../xmlActions/XmlCameraActionEditor.dart';
import '../xmlActions/XmlEnemyGeneratorActionEditor.dart';
import '../xmlActions/XmlEntityActionEditor.dart';
import '../xmlActions/XmlFadeActionEditor.dart';
import '../xmlActions/xmlArrayEditor.dart';
import 'XmlPropEditor.dart';
import 'propTextField.dart';

class XmlPresetContext {
  XmlProp parent;

  XmlPresetContext({required this.parent});

  OpenFileId? get file => parent.file;
  List<String> get parentTags => parent.nextParents();
  String? get parentName => parent.tagName;
}

class XmlRawPreset {
  final String name;
  final Widget Function<T extends PropTextField>(XmlProp prop, bool showDetails) editor;
  final FutureOr<XmlProp?> Function(XmlPresetContext cxt) propFactory;
  final XmlElement Function(XmlProp prop) duplicateAsXml;

  const XmlRawPreset(this.name, this.editor, this.propFactory, [this.duplicateAsXml = XmlRawPreset.defaultDuplicateAsXml]);

  XmlPreset withCxt(XmlPresetContext context) =>
    XmlPreset(name, editor, propFactory, context);

  XmlPreset withCxtV(XmlProp parent) =>
    XmlPreset(name, editor, propFactory, XmlPresetContext(parent: parent));

  static XmlElement defaultDuplicateAsXml(XmlProp prop) {
    return prop.toXml();
  }

  static XmlElement defaultDuplicateWithRandIdAsXml(XmlProp prop) {
    var xml = prop.toXml();
    var idEl = xml.getElement("id");
    if (idEl != null && idEl.text.startsWith("0x"))
      idEl.innerText = "0x${randomId().toRadixString(16)}";
    return xml;
  }

  static void updateLayoutsIdsInDuplicateXml(XmlElement layouts) {
    for (var child in layouts.childElements) {
      var idEl = child.getElement("id");
      if (idEl != null && idEl.text.startsWith("0x"))
        idEl.innerText = "0x${randomId().toRadixString(16)}";
      var subLayouts = child.getElement("layouts")!;
      for (var value in subLayouts.findElements("value")) {
        var idEl = value.getElement("id");
        if (idEl != null && idEl.text.startsWith("0x"))
          idEl.innerText = "0x${randomId().toRadixString(16)}";
      }
    }
  }
}

class XmlPreset extends XmlRawPreset {
  final XmlPresetContext? _context;

  const XmlPreset(super.name, super.editor, super.propFactory, this._context);

  FutureOr<XmlProp?> prop() => _context != null ? propFactory(_context!) : null;  
}

class XmlPresets {
  static XmlRawPreset area = XmlRawPreset(
    "Area",
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
    "Entity",
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
    XmlRawPreset.defaultDuplicateWithRandIdAsXml,
  );
  static XmlRawPreset layouts = XmlRawPreset(
    "Layouts",
    <T extends PropTextField>(prop, showDetails) => LayoutsEditor(prop: prop, showDetails: showDetails),
    (cxt) => null,
    (prop) {
      var xml = XmlRawPreset.defaultDuplicateWithRandIdAsXml(prop);
      XmlRawPreset.updateLayoutsIdsInDuplicateXml(xml);
      return xml;
    },
  );
  static XmlRawPreset params = XmlRawPreset(
    "Param",
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
        ...paramPresets.map((p) => SelectionPopupConfig(name: p.name, getValue: () => XmlProp.fromXml(
          makeXmlElement(
            name: "value",
            children: [
              makeXmlElement(name: "name", text: p.name),
              makeXmlElement(name: "code", text: "0x${crc32(p.code).toRadixString(16)}"),
              p.defaultValue != "[PUID]"
                ? makeXmlElement(name: "body", text: p.defaultValue)
                : makeXmlElement(name: "body", children: [
                    makeXmlElement(name: "id", children: [
                      makeXmlElement(name: "code", text: "0x0"),
                      makeXmlElement(name: "id", text: "0x0"),
                    ]),
                  ]),
            ]
          ),
          file: cxt.file,
          parentTags: cxt.parentTags,
        ))),
    ]));
  static XmlRawPreset condition = XmlRawPreset(
    "Condition",
    <T extends PropTextField>(prop, showDetails) => ConditionEditor(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(
        name: "value",
        children: [
          makeXmlElement(name: "puid", children: [
              makeXmlElement(name: "code", text: "0x0"),
              makeXmlElement(name: "id", text: "0x0"),
            ],
          ),
          makeXmlElement(name: "condition", children: [
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
    "Transforms",
    <T extends PropTextField>(prop, showDetails) => TransformsEditor(parent: prop),
    (cxt) => null,
  );
  static XmlRawPreset puidReference = XmlRawPreset(
    "PUID Reference",
    <T extends PropTextField>(prop, showDetails) => PuidReferenceEditor(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "puid", children: [
          makeXmlElement(name: "code", text: "0x0"),
          makeXmlElement(name: "id", text: "0x0"),
        ],
      ),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset command = XmlRawPreset(
    "Command",
    <T extends PropTextField>(prop, showDetails) => CommandEditor(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "value",
        children: [
          makeXmlElement(name: "puid", children: [
            makeXmlElement(name: "code", text: "0x0"),
            makeXmlElement(name: "id", text: "0x0"),
          ]),
          makeXmlElement(name: "command", children: [
            makeXmlElement(name: "command", children: [
              makeXmlElement(name: "label", text: "commandLabel"),
            ]),
          ]),
        ]
      ),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset codeAndId = XmlRawPreset(
    "Child",
    <T extends PropTextField>(prop, showDetails) => PuidReferenceEditor(
      prop: prop,
      showDetails: showDetails,
      initiallyShowLookup: (prop.get("code")!.value as HexProp).value != 0x0,
    ),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "value", children: [
          makeXmlElement(name: "code", text: "0x0"),
          makeXmlElement(name: "id", text: "0x0"),
        ],
      ),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset minMax = XmlRawPreset(
    "Child",
    <T extends PropTextField>(prop, showDetails) => MinMaxPropEditor<T>(prop: prop),
    (cxt) => throw UnimplementedError(),
  );
  static XmlRawPreset variable = XmlRawPreset(
    "Variable",
    <T extends PropTextField>(prop, showDetails) => ScriptVariableEditor<T>(prop: prop, showDetails: showDetails),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "value", children: [
        makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
        makeXmlElement(name: "name", text: "myVariable"),
        makeXmlElement(name: "value", children: [
          makeXmlElement(name: "code", text: "0x0"),
          makeXmlElement(name: "value", text: "0x0"),
        ]),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
    XmlRawPreset.defaultDuplicateWithRandIdAsXml,
  );
  static XmlRawPreset spawnNode = XmlRawPreset(
    "Node",
    <T extends PropTextField>(prop, showDetails) => XmlEmgSpawnNodeEditor(prop: prop, showDetails: showDetails,),
    (cxt) => XmlProp.fromXml(
      makeXmlElement(name: "value", children: [
        makeXmlElement(name: "point", text: "0.0 0.0 0.0"),
        makeXmlElement(name: "radius", text: "5.0"),
        makeXmlElement(name: "rate", text: "0"),
        makeXmlElement(name: "minDistance", text: "0"),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset scriptId = XmlRawPreset(
    "Child",
    <T extends PropTextField>(prop, showDetails) => ScriptIdEditor<T>(prop: prop),
    (cxt) => throw UnimplementedError(),
  );
  static XmlRawPreset dist = XmlRawPreset(
    "Child",
    <T extends PropTextField>(prop, showDetails) => DistEditor(dist: prop, showDetails: showDetails,),
    (cxt) => throw UnimplementedError(),
  );
  static XmlRawPreset points = XmlRawPreset(
    "Child",
    <T extends PropTextField>(prop, showDetails) => XmlEmgPointEditor(prop: prop, showDetails: showDetails,),
    (cxt) => throw UnimplementedError(),
  );

  static XmlRawPreset fallback = XmlRawPreset(
    "Child",
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

final Map<int, Widget Function(XmlActionProp action, bool showDetails)> _innerActionEditors = {
  crc32("EnemyGenerator"): (action, showDetails) => EnemyGeneratorInnerEditor(action: action, showDetails: showDetails),
  crc32("EntityLayoutAction"): (action, showDetails) => EntityActionInnerEditor(action: action, showDetails: showDetails),
  crc32("EntityLayoutArea"): (action, showDetails) => EntityActionInnerEditor(action: action, showDetails: showDetails),
  crc32("EnemySetAction"): (action, showDetails) => EntityActionInnerEditor(action: action, showDetails: showDetails),
  crc32("EnemySetArea"): (action, showDetails) => EntityActionInnerEditor(action: action, showDetails: showDetails),
  crc32("SQ090_Layout"): (action, showDetails) => EntityActionInnerEditor(action: action, showDetails: showDetails),
  crc32("CameraAction"): (action, showDetails) => CameraActionInnerEditor(action: action, showDetails: showDetails),
  crc32("FadeAction"): (action, showDetails) => FadeActionInnerEditor(action: action, showDetails: showDetails),
};

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
  if (prop.get("puid") != null && prop.get("command") != null && prop.get("id") == null) {
    return XmlPresets.command;
  }
  // variable
  if (prop.length == 3 && prop[0].tagName == "id" && prop[1].tagName == "name" && prop[2].tagName == "value") {
    return XmlPresets.variable;
  }
  // min max
  if (
    prop.length == 2 && prop.get("min") != null && prop.get("max") != null ||
    prop.length == 1 && { "min", "max" }.contains(prop[0].tagName)  
  ) {
    return XmlPresets.minMax;
  }
  // code and id
  if (prop.length == 2 && prop[0].tagName == "code" && prop[1].tagName == "id") {
    return XmlPresets.codeAndId;
  }
  // script id
  if (prop.tagName == "script" && prop.length == 1 && prop[0].tagName == "id") {
    return XmlPresets.scriptId;
  }
  // dist
  if (prop.tagName == "dist") {
    return XmlPresets.dist;
  }
  // points
  if (prop.tagName == "points" && prop.length == 2) {
    return XmlPresets.points;
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
    if (filter != null && !filter(child)) {
      continue;
    }
    if (_skipPropNames.contains(child.tagName)) {
      continue;
    }
    var context = XmlPresetContext(parent: child);
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
    // Custom Actions
    else if (i == 4 && parent is XmlActionProp && _innerActionEditors.containsKey(parent.code.value)) {
      var innerEditor = _innerActionEditors[parent.code.value]!.call(parent, showDetails);
      widgets.add(innerEditor);
      break;
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
final _puidRefCodes = puidCodes
  .map((c) => crc32(c))
  .toSet();

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
