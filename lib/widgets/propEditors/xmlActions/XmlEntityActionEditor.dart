
import 'package:flutter/material.dart';

import '../../../stateManagement/openFiles/types/xml/sync/syncListImplementations.dart';
import '../../misc/syncButton.dart';
import '../customXmlProps/layoutsEditor.dart';
import 'XmlActionEditor.dart';
import 'XmlActionInnerEditor.dart';

class XmlEntityActionEditor extends XmlActionEditor {
  XmlEntityActionEditor({ super.key,  required super.action, required super.showDetails });

  @override
  State<XmlEntityActionEditor> createState() => _XmlEntityActionEditorState();
}

class _XmlEntityActionEditorState extends XmlActionEditorState<XmlEntityActionEditor> {
  @override
  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      SyncButton(
        uuid: widget.action.uuid,
        makeSyncedObject: () => SyncedEntityAction(
          action: widget.action,
          parentUuid: "",
        ),
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }

  @override
  Widget makeInnerActionBody() {
    return EntityActionInnerEditor(
      action: widget.action,
      showDetails: widget.showDetails,
    );
  }
}

class EntityActionInnerEditor extends XmlActionInnerEditor {
  EntityActionInnerEditor({ super.key, required super.action, required super.showDetails});

  @override
  State<EntityActionInnerEditor> createState() => _EntityActionInnerEditorState();
}

class _EntityActionInnerEditorState extends XmlActionInnerEditorState<EntityActionInnerEditor> {
  @override
  Widget build(BuildContext context) {
    var layouts = widget.action.get(_layoutsTag)!;
    var areaProps = widget.action.where((e) => _areaTags.contains(e.tagName)).toList();
    var enemySetProps = widget.action.where((e) => _enemySetTags.contains(e.tagName)).toList();
    var enemySetAreaProps = widget.action.where((e) => _enemySetAreaTags.contains(e.tagName)).toList();
    bool onlyLayouts = areaProps.isEmpty && enemySetProps.isEmpty && enemySetAreaProps.isEmpty;
    
    return Column(
      children: [
        makeGroupWrapperCustom("Spawn Entities", LayoutsEditor(prop: layouts, showDetails: widget.showDetails)),
        if (!onlyLayouts)
          makeSeparator(),
        if (areaProps.isNotEmpty) ...[
          makeGroupWrapperSingle("Spawn Areas", areaProps),
          if (enemySetProps.isNotEmpty || enemySetAreaProps.isNotEmpty)
            makeSeparator(),
        ],
        if (enemySetProps.isNotEmpty) ...[
          makeGroupWrapperSingle("Enemy Set Properties", enemySetProps),
          if (enemySetAreaProps.isNotEmpty)
            makeSeparator(),
        ],
        if (enemySetAreaProps.isNotEmpty)
          makeGroupWrapperSingle("Enemy Behavior Properties", enemySetAreaProps),
      ],
    );
  }
}

const _layoutsTag = "layouts";
const _areaTags = { "area", "resetArea", "resetType" };
const _enemySetTags = { "condition", "delay", "max", "param" };
const _enemySetAreaTags = { "searchArea", "escapeArea", "dist" };
