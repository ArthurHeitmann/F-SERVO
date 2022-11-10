
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/sync/syncObjects.dart';
import '../../../utils/utils.dart';
import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import 'puidReferenceEditor.dart';

class LayoutsEditor extends StatelessWidget {
  final bool showDetails;
  final XmlProp prop;

  const LayoutsEditor({super.key, required this.prop, required this.showDetails});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDetails)
          Row(
            children: [
              Text("parent", style: getTheme(context).propInputTextStyle,),
              const SizedBox(width: 10),
              Flexible(
                child: PuidReferenceEditor(prop: prop.get("normal")!.get("parent")!.get("id")!.get("id")!, showDetails: showDetails)
              ),
            ],
          ),
        NestedContextMenu(
          buttons: [
            ContextMenuButtonConfig(
              "Sync to Blender",
              icon: const Icon(Icons.sync, size: 14,),
              onPressed: () => startSyncingObject(SyncedList<XmlProp>(
                list: prop.get("normal")!.get("layouts")!,
                filter: (prop) => prop.tagName == "value",
                parentUuid: prop.file?.uuid ?? "root",
                makeSyncedObj: (prop, parentUuid) => EntitySyncedObject(prop, parentUuid: parentUuid),
                makeCopy: (prop, uuid) {
                  var newProp = XmlProp.fromXml(prop.toXml(), parentTags: prop.parentTags, file: prop.file);
                  (newProp.get("id")!.value as HexProp).value = randomId();
                  return newProp;
                },
              ))
            ),
          ],
          child: makeXmlPropEditor(prop.get("normal")!.get("layouts")!, showDetails),
        ),
      ],
    );
  }
}
