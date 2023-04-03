
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/sync/syncListImplementations.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../../misc/syncButton.dart';
import '../../theme/customTheme.dart';
import '../customXmlProps/distEditor.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import 'XmlActionEditor.dart';

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

  @override
  Widget makeInnerActionBody() {
    return EnemyGeneratorInnerEditor(
      action: widget.action,
      showDetails: widget.showDetails,
    );
  }  
}

class EnemyGeneratorInnerEditor extends ChangeNotifierWidget {
  final XmlProp action;
  final bool showDetails;

  EnemyGeneratorInnerEditor({ super.key, required this.action, required this.showDetails })
    : super(notifier: action);

  @override
  State<EnemyGeneratorInnerEditor> createState() => _EnemyGeneratorEditorState();
}

class _EnemyGeneratorEditorState extends ChangeNotifierState<EnemyGeneratorInnerEditor> {
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
          _makeSeparator(),
        ],
        if (spawnEntities != null) ...[
          _makeGroupWrapperMulti("Spawn Entities", [spawnEntities]),
          _makeSeparator(),
        ],
        if (minMaxProps.isNotEmpty) ...[
          _minMaxWrapper(
            child: _makeGroupWrapperSingle("Min/Max", minMaxProps)
          ),
          _makeSeparator(),
        ],
        if (inBetweenProps.isNotEmpty && widget.showDetails) ...[
          _inBetweenWrapper(
            child: Column(
              children: inBetweenProps
                .map((prop) => makeXmlPropEditor(prop, widget.showDetails))
                .toList(),
            ),
          ),
          _makeSeparator(),
        ],
        if (areaProps.isNotEmpty) ...[
          _makeGroupWrapperSingle("Areas", areaProps),
          _makeSeparator(),
        ],
        if (distProp != null) ...[
          _makeGroupWrapperCustom("Distances", DistEditor(dist: distProp, showDetails: widget.showDetails, showTagName: false,)),
          if (trailingProps.isNotEmpty && widget.showDetails)
            _makeSeparator(),
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
          () => _makeMinMaxProps(2.0, 10.0, false),
        ),
        optionalPropButtonConfig(
          widget.action, "levelRange", () => getNextInsertIndexAfter(widget.action, ["createRange"]),
          () => _makeMinMaxProps(20, 30, true),
        ),
        optionalPropButtonConfig(
          widget.action, "spawnInterval", () => getNextInsertIndexAfter(widget.action, ["levelRange", "createRange"]),
          () => _makeMinMaxProps(2.0, 5.0, false),
        ),
        optionalPropButtonConfig(
          widget.action, "amountEachSpawn", () => getNextInsertIndexAfter(widget.action, ["spawnInterval", "levelRange", "createRange"]),
          () => _makeMinMaxProps(2, 5, true),
        ),
      ],
      child: child,
    );
  }
  List<XmlProp> _makeMinMaxProps(num min, num max, bool isInt) {
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

  Widget _makeGroupWrapperSingle(String title, Iterable<XmlProp> props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(title, style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        for (var prop in props)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: makeXmlPropEditor(prop, widget.showDetails),
          )
      ],
    );
  }
  Widget _makeGroupWrapperMulti(String title, Iterable<XmlProp> props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(title, style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        ...props.map((prop) => makeXmlMultiPropEditor(prop, widget.showDetails)
          .map((child) => Padding(
            key: child.key != null ? ValueKey(child.key) : null,
            padding: const EdgeInsets.only(left: 10),
            child: child,
          ))
        ).expand((e) => e),
      ],
    );
  }
  Widget _makeGroupWrapperCustom(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(title, style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: child,
        ),
      ],
    );
  }
  Widget _makeSeparator() {
    return const Divider(
      height: 20,
      thickness: 1,
      indent: 10,
      endIndent: 10,
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
