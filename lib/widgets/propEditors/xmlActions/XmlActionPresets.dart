
import 'package:xml/xml.dart';

import '../../../main.dart';
import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/selectionPopup.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propTextField.dart';
import 'XmlActionEditorFactory.dart';

XmlElement _makeAction(String code, List<XmlElement> children, { int attribute = 0 }) {
  return makeXmlElement(name: "action", children: [
    makeXmlElement(name: "code", text: "0x${crc32(code).toRadixString(16)}"),
    makeXmlElement(name: "name", text: "new $code action"),
    makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
    makeXmlElement(name: "attribute", text: "0x${attribute.toRadixString(16)}"),
    ...children,
  ]);
}

XmlElement _makePuid() {
  return makeXmlElement(name: "puid",
    children: [
      makeXmlElement(name: "code", text: "0x0"),
      makeXmlElement(name: "id", text: "0x0"),
    ],
  );
}

XmlElement _makeLayout(String name, { int flags = 0 }) {
  return makeXmlElement(name: name,
    children: [
      makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
      makeXmlElement(name: "flags", text: "0x${flags.toRadixString(16)}"),
      makeXmlElement(name: "parent", children: [
        makeXmlElement(name: "id", children: [
          makeXmlElement(name: "id", children: [
            makeXmlElement(name: "code", text: "0x0"),
            makeXmlElement(name: "id", text: "0x0"),
          ]),
        ]),
      ]),
      makeXmlElement(name: "layouts", children: [
        makeXmlElement(name: "size", text: "0"),
      ]),
    ],
  );
}

XmlElement _makeArea() {
  return makeXmlElement(
    name: "value",
    children: [
      makeXmlElement(name: "code", text: "0x${crc32("app::area::BoxArea").toRadixString(16)}"),
      makeXmlElement(name: "position", text: "0 0 0"),
      makeXmlElement(name: "rotation", text: "0 0 0"),
      makeXmlElement(name: "scale", text: "1 1 1"),
      makeXmlElement(name: "points", text: "-1 -1 1 -1 1 1 -1 1"),
      makeXmlElement(name: "height", text: "1"),
    ]
  );
}

class XmlActionPresets {
  static XmlRawPreset action = XmlRawPreset(
    "Action",
    <T extends PropTextField>(prop, showDetails) => makeXmlActionEditor(
      action: prop as XmlActionProp,
      showDetails: showDetails,
    ),
    (cxt) => showSelectionPopup(getGlobalContext(), _actionPreset
      .entries
      .map((e) => SelectionPopupConfig(
        name: e.key,
        getValue: () => e.value.withCxt(cxt).prop()! as XmlProp)
      )
      .toList()
    ),
  );

  static XmlRawPreset sendCommand = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("SendCommand", [
        _makePuid(),
        makeXmlElement(name: "command", children: [
          makeXmlElement(name: "label", text: "commandLabel"),
        ])
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset sendCommands = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("SendCommands", [
        makeXmlElement(name: "commands", children: [
          makeXmlElement(name: "items", children: [
            makeXmlElement(name: "size", text: "1"),
            makeXmlElement(name: "value", children: [
              _makePuid(),
              makeXmlElement(name: "command", children: [
                makeXmlElement(name: "command", children: [
                  makeXmlElement(name: "label", text: "commandLabel"),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset conditionBlock = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("ConditionBlock", [
        makeXmlElement(name: "condition", children: [
          _makePuid(),
          makeXmlElement(name: "condition", children: [
            makeXmlElement(name: "state", children: [
              makeXmlElement(name: "label", text: "conditionLabel"),
            ]),
            makeXmlElement(name: "pred", text: "0"),
          ]),
        ]),
        makeXmlElement(name: "delay", text: "0"),
        makeXmlElement(name: "bDisable", text: "0"),
      ], attribute: 0x8),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset entityLayout = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("EntityLayoutAction", [
        makeXmlElement(name: "layouts", children: [
          _makeLayout("normal", flags: 0),
          _makeLayout("hard", flags: 1),
          _makeLayout("extream", flags: 1),
        ]),
        makeXmlElement(name: "bForwardState", text: "0"),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset entityLayoutArea = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("EntityLayoutArea", [
        makeXmlElement(name: "layouts", children: [
          _makeLayout("normal", flags: 0),
          _makeLayout("hard", flags: 1),
          _makeLayout("extream", flags: 1),
        ]),
        makeXmlElement(name: "bForwardState", text: "0"),
        makeXmlElement(name: "area", children: [
          makeXmlElement(name: "size", text: "1"),
          _makeArea(),
        ]),
        makeXmlElement(name: "resetArea", children: [
          makeXmlElement(name: "size", text: "0"),
        ]),
        makeXmlElement(name: "resetType", text: "0"),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset enemySet = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("EnemySetAction", [
        makeXmlElement(name: "layouts", children: [
          _makeLayout("normal", flags: 0),
          _makeLayout("hard", flags: 1),
          _makeLayout("extream", flags: 1),
        ]),
        makeXmlElement(name: "condition", children: [
          _makePuid(),
          makeXmlElement(name: "condition", children: [
            makeXmlElement(name: "state"),
            makeXmlElement(name: "pred", text: "0"),
          ]),
        ]),
        makeXmlElement(name: "delay", text: "0"),
        makeXmlElement(name: "max", text: "0"),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset enemySetArea = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("EnemySetArea", [
        makeXmlElement(name: "layouts", children: [
          _makeLayout("normal", flags: 0),
          _makeLayout("hard", flags: 1),
          _makeLayout("extream", flags: 1),
        ]),
        makeXmlElement(name: "condition", children: [
          _makePuid(),
          makeXmlElement(name: "condition", children: [
            makeXmlElement(name: "state"),
            makeXmlElement(name: "pred", text: "0"),
          ]),
        ]),
        makeXmlElement(name: "delay", text: "0"),
        makeXmlElement(name: "max", text: "0"),
        makeXmlElement(name: "area", children: [
          makeXmlElement(name: "size", text: "1"),
          _makeArea(),
        ]),
        makeXmlElement(name: "resetArea", children: [
          makeXmlElement(name: "size", text: "0"),
        ]),
        makeXmlElement(name: "resetType", text: "3"),
        makeXmlElement(name: "searchArea", children: [
          makeXmlElement(name: "size", text: "0"),
        ]),
        makeXmlElement(name: "escapeArea", children: [
          makeXmlElement(name: "size", text: "0"),
        ]),
        makeXmlElement(name: "dist", children: [
          makeXmlElement(name: "areaDist", text: "150"),
          makeXmlElement(name: "resetDist", text: "170"),
          makeXmlElement(name: "searchDist", text: "50"),
          makeXmlElement(name: "guardSDist", text: "60"),
          makeXmlElement(name: "guardLDist", text: "70"),
          makeXmlElement(name: "escapeDist", text: "80"),
        ]),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset conditionCommands = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("ConditionCommands", [
        makeXmlElement(name: "condition", children: [
          makeXmlElement(name: "conditions", children: [
            makeXmlElement(name: "size", text: "1"),
            makeXmlElement(name: "value", children: [
              _makePuid(),
              makeXmlElement(name: "condition", children: [
                makeXmlElement(name: "state", children: [
                  makeXmlElement(name: "label", text: "conditionLabel"),
                ]),
                makeXmlElement(name: "pred", text: "0")
              ]),
            ]),
          ]),
          makeXmlElement(name: "type", text: "0"),
        ]),
        makeXmlElement(name: "commands", children: [
          makeXmlElement(name: "items", children: [
            makeXmlElement(name: "size", text: "1"),
            makeXmlElement(name: "value", children: [
              _makePuid(),
              makeXmlElement(name: "command", children: [
                makeXmlElement(name: "command", children: [
                  makeXmlElement(name: "label", text: "commandLabel"),
                ]),
              ]),
            ]),
          ]),
        ]),
        makeXmlElement(name: "type_", text: "2"),
        makeXmlElement(name: "delay", text: "0"),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset area = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("AreaAction", [
        makeXmlElement(name: "area", children: [
          makeXmlElement(name: "size", text: "1"),
          _makeArea(),
        ]),
      ], attribute: 0x8),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset delay = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("DelayAction", [
        makeXmlElement(name: "delay", text: "1"),
      ], attribute: 0x8),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset script = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("ScriptAction", [
        makeXmlElement(name: "curve", children: [
        ]),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
  static XmlRawPreset bezierCurve = XmlRawPreset(
    "Action",
    XmlActionPresets.action.editor,
    (cxt) => XmlProp.fromXml(
      _makeAction("BezierCurveAction", [
        makeXmlElement(name: "curve", children: [
          makeXmlElement(name: "attribute", text: "0x0"),
          makeXmlElement(name: "controls", children: [
            makeXmlElement(name: "size", text: "2"),
            makeXmlElement(name: "value", children: [
              makeXmlElement(name: "cp", text: "-3 0 0 -3 0 0"),
            ]),
            makeXmlElement(name: "value", children: [
              makeXmlElement(name: "cp", text: "5 0 0 5 0 0"),
            ]),
          ]),
          makeXmlElement(name: "nodes", children: [
            makeXmlElement(name: "size", text: "2"),
            makeXmlElement(name: "value", children: [
              makeXmlElement(name: "point", text: "-4 0 0"),
            ]),
            makeXmlElement(name: "value", children: [
              makeXmlElement(name: "point", text: "4 0 0"),
            ]),
          ]),
        ]),
      ]),
      file: cxt.file,
      parentTags: cxt.parentTags,
    ),
  );
}

final _actionPreset = {
  "SendCommand": XmlActionPresets.sendCommand,
  "SendCommands": XmlActionPresets.sendCommands,
  "ConditionBlock": XmlActionPresets.conditionBlock,
  "ConditionCommands": XmlActionPresets.conditionCommands,
  "EntityLayoutAction": XmlActionPresets.entityLayout,
  "EntityLayoutArea": XmlActionPresets.entityLayoutArea,
  "EnemySetAction": XmlActionPresets.enemySet,
  "EnemySetArea": XmlActionPresets.enemySetArea,
  "AreaAction": XmlActionPresets.area,
  "DelayAction": XmlActionPresets.delay,
  "ScriptAction": XmlActionPresets.script,
  "BezierCurveAction": XmlActionPresets.bezierCurve,
};
