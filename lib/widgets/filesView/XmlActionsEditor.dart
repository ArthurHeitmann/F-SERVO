
import 'package:flutter/material.dart';

import '../../stateManagement/sync/syncListImplementations.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../utils/utils.dart';
import '../misc/FlexReorderable.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../misc/nestedContextMenu.dart';
import '../misc/syncButton.dart';
import '../propEditors/xmlActions/XmlActionEditorFactory.dart';
import '../propEditors/xmlActions/XmlActionPresets.dart';
import '../propEditors/xmlActions/actionAddButton.dart';
import '../propEditors/xmlActions/xmlArrayEditor.dart';
import 'xmlJumpToLineEventWrapper.dart';


class XmlActionsEditor extends XmlArrayEditor {
  final XmlProp root;

  XmlActionsEditor({super.key, required this.root})
    : super(root, XmlActionPresets.action, root.where((element) => element.tagName == "size").first, "action", false);

  @override
  XmlArrayEditorState createState() => _XmlActionsEditorState();
}

class _XmlActionsEditorState extends XmlArrayEditorState<XmlActionsEditor> {
  final scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    var actions = getChildProps().toList();
    return Stack(
      fit: StackFit.expand,
      children: [
        SmoothSingleChildScrollView(
          controller: scrollController,
          child: XmlJumpToLineEventWrapper(
            file: widget.root.file!,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ColumnReorderable(
                crossAxisAlignment: CrossAxisAlignment.start,
                onReorder: (int oldIndex, int newIndex) {
                if (oldIndex < 0 || oldIndex >= widget.parent.length || newIndex < 0 || newIndex >= widget.parent.length) {
                  print("Invalid reorder: $oldIndex -> $newIndex (length: ${widget.parent.length})");
                  return;
                }
                  widget.root.move(oldIndex + firstChildOffset, newIndex + firstChildOffset);
                },
                header: ActionAddButton(parent: widget.root, index: 0),
                children: actions.map((action) {
                  var actionEditor = makeXmlActionEditor(
                    action: action as XmlActionProp,
                    showDetails: false,
                  );
                  return Column(
                    key: makeReferenceKey(actionEditor.key!),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NestedContextMenu(
                        buttons: getContextMenuButtons(actions.indexOf(action)),
                        child: actionEditor
                      ),
                      ActionAddButton(parent: widget.root, index: actions.indexOf(action) + 1),
                    ],
                  );
                })
                .toList(),
              ),
            ),
          ),
        ),
        _makeSyncButton(),
      ],
    );
  }

  Widget _makeSyncButton() {
    return Positioned(
      top: 12,
      right: 12,
      child: SyncButton(
        uuid: widget.root.uuid,
        makeSyncedObject: () => SyncedXmlFile(
          list: widget.root,
          parentUuid: "",
          nameHint: widget.root.file?.displayName
        ),
      ),
    );
  }
}
