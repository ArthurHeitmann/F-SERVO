
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncObjects.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/nestedContextMenu.dart';
import 'XmlActionEditor.dart';

class XmlEntityActionEditor extends XmlActionEditor {
  XmlEntityActionEditor({ required super.action, required super.showDetails });

  @override
  State<XmlEntityActionEditor> createState() => _XmlEntityActionEditorState();
}

class _XmlEntityActionEditorState extends XmlActionEditorState<XmlEntityActionEditor> {
  @override
  Widget build(BuildContext context) {
    return NestedContextMenu(
      buttons: [
        ContextMenuButtonConfig(
          "Sync Action to Blender",
          icon: const Icon(Icons.sync, size: 14,),
          onPressed: () => startSyncingObject(SyncedList<XmlProp>(
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
          ))
        )
      ],
      child: super.build(context),
    );
  }
}
