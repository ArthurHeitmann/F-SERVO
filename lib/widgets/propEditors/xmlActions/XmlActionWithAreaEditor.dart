
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncObjects.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/syncButton.dart';
import 'XmlActionEditor.dart';

class XmlActionWithAreaEditor extends XmlActionEditor {
  XmlActionWithAreaEditor({ super.key, required super.action, required super.showDetails});

  @override
  State<XmlActionWithAreaEditor> createState() => _XmlActionWithAreaEditorState();
}

class _XmlActionWithAreaEditorState extends XmlActionEditorState<XmlActionWithAreaEditor> {
  @override
  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      SyncButton(
        uuid: widget.action.uuid,
        makeSyncedObject: () => SyncedList<XmlProp>(
          list: widget.action,
          parentUuid: "",
          nameHint: widget.action.name.value,
          filter: (prop) => prop.tagName.toLowerCase().contains("area") && prop.get("size") != null,
          makeSyncedObj: (prop, parentUuid) => SyncedXmlList(
            list: prop,
            parentUuid: parentUuid,
            listType: "area",
            nameHint: prop.tagName,
            makeSyncedObj: (prop, parentUuid) => AreaSyncedObject(prop, parentUuid: parentUuid),
            allowReparent: false,
            allowListChange: true,
          ),
          makeCopy: (prop, uuid) => throw UnimplementedError(),
          listType: "areaAction",
          allowReparent: true,
          allowListChange: false,
        )
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}
