
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncObjects.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/syncButton.dart';
import 'XmlActionEditor.dart';

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
        makeSyncedObject: () => SyncedList<XmlProp>(
          list: widget.action,
          parentUuid: "",
          nameHint: widget.action.name.value,
          filter: (prop) => prop.tagName == "layouts" || prop.tagName.toLowerCase().contains("area"),
          makeSyncedObj: (prop, parentUuid) {
            if (prop.tagName == "layouts") {
              return SyncedEntityList(
                list: prop.get("normal")?.get("layouts")! ?? prop.get("layouts")!,
                parentUuid: parentUuid,
              );
            } else {
              return SyncedAreaList(
                list: prop,
                parentUuid: parentUuid,
                nameHint: prop.tagName,
              );
            }
          },
          makeCopy: (prop, uuid) => throw UnimplementedError(),
          listType: "entityAction",
          allowReparent: true,
          allowListChange: false
        )
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}
