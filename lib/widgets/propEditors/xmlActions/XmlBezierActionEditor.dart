
import 'package:flutter/material.dart';

import '../../../stateManagement/openFiles/types/xml/sync/syncListImplementations.dart';
import '../../misc/syncButton.dart';
import 'XmlActionEditor.dart';

class XmlBezierActionEditor extends XmlActionEditor {
  XmlBezierActionEditor({super.key, required super.action, required super.showDetails});

  @override
  State<XmlBezierActionEditor> createState() => _XmlBezierActionEditorState();
}

class _XmlBezierActionEditorState extends XmlActionEditorState<XmlBezierActionEditor> {
  @override
  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      SyncButton(
        uuid: widget.action.uuid,
        makeSyncedObject: () => SyncedBezierAction(
          action: widget.action,
          parentUuid: "",
        )
      ),
      ...super.getRightHeaderButtons(context),	
    ];
  }
}
