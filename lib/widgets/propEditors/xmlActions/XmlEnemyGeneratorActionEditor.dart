
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncListImplementations.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/syncButton.dart';
import '../../theme/customTheme.dart';
import '../customXmlProps/distEditor.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propEditorFactory.dart';
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
          _makeGroupWrapperSingle("Min/Max", minMaxProps),
          _makeSeparator(),
        ],
        if (inBetweenProps.isNotEmpty && widget.showDetails) ...[
          ...inBetweenProps.map((prop) => makeXmlPropEditor(prop, widget.showDetails)),
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
