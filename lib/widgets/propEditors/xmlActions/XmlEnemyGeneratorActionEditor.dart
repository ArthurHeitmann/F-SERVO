
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncListImplementations.dart';
import '../../misc/syncButton.dart';
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
}
