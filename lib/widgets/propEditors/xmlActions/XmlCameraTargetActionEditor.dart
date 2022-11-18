
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncListImplementations.dart';
import '../../misc/syncButton.dart';
import 'XmlActionEditor.dart';

class XmlCameraTargetActionEditor extends XmlActionEditor {
  XmlCameraTargetActionEditor({super.key, required super.action, required super.showDetails});

  @override
  State<XmlCameraTargetActionEditor> createState() => _XmlCameraTargetActionEditorState();
}

class _XmlCameraTargetActionEditorState extends XmlActionEditorState<XmlCameraTargetActionEditor> {
  @override
  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      SyncButton(
        uuid: widget.action.uuid,
        makeSyncedObject: () => SyncedCameraTargetAction(
          action: widget.action,
          parentUuid: "",
        )
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}
