
import 'package:flutter/material.dart';

import '../../../stateManagement/openFiles/types/xml/sync/syncListImplementations.dart';
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
        makeSyncedObject: () => SyncedAreasAction(
          action: widget.action,
          parentUuid: "",
        )
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}
