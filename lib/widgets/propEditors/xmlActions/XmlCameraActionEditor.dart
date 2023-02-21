
import 'package:flutter/material.dart';

import '../../../stateManagement/sync/syncListImplementations.dart';
import '../../misc/syncButton.dart';
import 'XmlActionEditor.dart';

class XmlCameraActionEditor extends XmlActionEditor {
  XmlCameraActionEditor({super.key, required super.action, required super.showDetails});

  @override
  State<XmlCameraActionEditor> createState() => _XmlCameraActionEditorState();
}

class _XmlCameraActionEditorState extends XmlActionEditorState<XmlCameraActionEditor> {
  @override
  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      SyncButton(
        uuid: widget.action.uuid,
        makeSyncedObject: () => SyncedCameraAction(
          action: widget.action,
          parentUuid: "",
        )
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}
