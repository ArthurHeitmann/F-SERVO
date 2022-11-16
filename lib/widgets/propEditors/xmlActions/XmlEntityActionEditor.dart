
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncObjects.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/nestedContextMenu.dart';
import '../../misc/syncButton.dart';
import 'XmlActionEditor.dart';

class XmlEntityActionEditor extends XmlActionEditor {
  // ignore: use_key_in_widget_constructors
  XmlEntityActionEditor({ required super.action, required super.showDetails });

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
          nameHint: widget.action.get("name")!.value.toString(),
          filter: (prop) => { "layouts", "area" }.contains(prop.tagName),
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
