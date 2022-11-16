
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncListImplementations.dart';
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
        makeSyncedObject: () => SyncedEntityAction(
          action: widget.action,
          parentUuid: "",
        ),
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}
