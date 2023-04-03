
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/sync/syncListImplementations.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../../misc/syncButton.dart';
import '../customXmlProps/distEditor.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import 'XmlActionEditor.dart';
import 'XmlActionInnerEditor.dart';

class XmlEnemyGeneratorActionEditor extends XmlActionEditor {
  XmlEnemyGeneratorActionEditor({super.key, required super.action, required super.showDetails});

  @override
  State<XmlEnemyGeneratorActionEditor> createState() => _XmlEnemyGeneratorActionEditorState();
}

class _XmlEnemyGeneratorActionEditorState extends XmlActionEditorState<XmlEnemyGeneratorActionEditor> {
  @override
  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      SyncButton(
        uuid: widget.action.uuid,
        makeSyncedObject: () => SyncedEMGeneratorAction(
          action: widget.action,
          parentUuid: "",
        )
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}

class EnemyGeneratorInnerEditor extends XmlActionInnerEditor {

  EnemyGeneratorInnerEditor({ super.key, required super.action, required super.showDetails });

  @override
  State<EnemyGeneratorInnerEditor> createState() => _EnemyGeneratorEditorState();
}

class _EnemyGeneratorEditorState extends XmlActionInnerEditorState<EnemyGeneratorInnerEditor> {
  @override
  Widget build(BuildContext context) {
    var spawnNodes = widget.action.get("points");
    var spawnEntities = widget.action.get("items");
    var minMaxProps = widget.action.where((e) => _minMaxProperties.contains(e.tagName));
    var inBetweenProps = widget.action.where((e) => _inBetweenProperties.contains(e.tagName));
    var areaProps = widget.action.where((e) => _areaProperties.contains(e.tagName));
    var distProp = widget.action.get("dist");
    var trailingProps = widget.action.where((e) => _trailingProperties.contains(e.tagName));
    return Column(
      children: [
        if (spawnNodes != null) ...[
          makeXmlPropEditor(spawnNodes, widget.showDetails),
          makeSeparator(),
        ],
        if (spawnEntities != null) ...[
          makeGroupWrapperMulti("Spawn Entities", [spawnEntities]),
          makeSeparator(),
        ],
        if (minMaxProps.isNotEmpty) ...[
          _minMaxWrapper(
            child: makeGroupWrapperSingle("Min/Max", minMaxProps)
          ),
          makeSeparator(),
        ],
        if (inBetweenProps.isNotEmpty && widget.showDetails) ...[
          _inBetweenWrapper(
            child: Column(
              children: inBetweenProps
                .map((prop) => makeXmlPropEditor(prop, widget.showDetails))
                .toList(),
            ),
          ),
          makeSeparator(),
        ],
        if (areaProps.isNotEmpty) ...[
          makeGroupWrapperSingle("Areas", areaProps),
          makeSeparator(),
        ],
        if (distProp != null) ...[
          makeGroupWrapperCustom("Distances", DistEditor(dist: distProp, showDetails: widget.showDetails, showTagName: false,)),
          if (trailingProps.isNotEmpty && widget.showDetails)
            makeSeparator(),
        ],
        if (trailingProps.isNotEmpty && widget.showDetails) ...[
          ...trailingProps.map((prop) => makeXmlPropEditor(prop, widget.showDetails)),
        ],
      ],
    );
  }

  Widget _minMaxWrapper({ required Widget child }) {
    return NestedContextMenu(
      buttons: [
        optionalPropButtonConfig(
          widget.action, "respawnTime", () => 6,
          () => makeMinMaxProps(2.0, 10.0, false),
        ),
        optionalPropButtonConfig(
          widget.action, "levelRange", () => getNextInsertIndexAfter(widget.action, ["createRange"]),
          () => makeMinMaxProps(20, 30, true),
        ),
        optionalPropButtonConfig(
          widget.action, "spawnInterval", () => getNextInsertIndexAfter(widget.action, ["levelRange", "createRange"]),
          () => makeMinMaxProps(2.0, 5.0, false),
        ),
        optionalPropButtonConfig(
          widget.action, "amountEachSpawn", () => getNextInsertIndexAfter(widget.action, ["spawnInterval", "levelRange", "createRange"]),
          () => makeMinMaxProps(2, 5, true),
        ),
      ],
      child: child,
    );
  }
  List<XmlProp> makeMinMaxProps(num min, num max, bool isInt) {
    return [
      XmlProp(
        file: widget.action.file,
        tagId: crc32("min"), tagName: "min",
        value: NumberProp(min, isInt),
        parentTags: widget.action.nextParents()
      ),
      XmlProp(
        file: widget.action.file,
        tagId: crc32("max"), tagName: "max",
        value: NumberProp(max, isInt),
        parentTags: widget.action.nextParents()
      ),
    ];
  }
  Widget _inBetweenWrapper({ required Widget child }) {
    return NestedContextMenu(
      buttons: [
        optionalValPropButtonConfig(
          widget.action, "cameraType", () => getNextInsertIndexBefore(widget.action, ["relativeLevel"]),
          () => NumberProp(-1, true)
        ),
      ],
      child: child,
    );
  }
}

const _minMaxProperties = {
  "respawnTime",
  "spawnRange",
  "createRange",
  "levelRange",
  "spawnInterval",
  "amountEachSpawn",
};

const _inBetweenProperties = {
  "cameraType",
  "relativeLevel",
};

const _areaProperties = {
  "area",
  "resetArea",
  "resetType",
  "searchArea",
  "escapeType",
};

const _trailingProperties = {
  "fitGround",
  "stateBeforeDeactivated",
};
