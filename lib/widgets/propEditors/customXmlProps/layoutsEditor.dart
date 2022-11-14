
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncObjects.dart';
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
              onPressed: () => startSyncingObject(SyncedEntityList(
                list: prop.get("normal")!.get("layouts")!,
                parentUuid: "",
              ))
            ),
          ],
          child: makeXmlPropEditor(prop.get("normal")!.get("layouts")!, showDetails),
        ),
      ],
    );
  }
}
