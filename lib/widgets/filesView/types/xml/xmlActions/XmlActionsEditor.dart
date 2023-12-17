
import 'package:flutter/material.dart';

import '../../../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../../../stateManagement/openFiles/types/xml/sync/syncListImplementations.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlActionProp.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../../../utils/utils.dart';
import '../../../../misc/FlexReorderable.dart';
import '../../../../misc/Selectable.dart';
import '../../../../misc/SmoothScrollBuilder.dart';
import '../../../../misc/nestedContextMenu.dart';
import '../../../../misc/syncButton.dart';
import '../xmlJumpToLineEventWrapper.dart';
import 'XmlActionEditor.dart';
import 'XmlActionEditorFactory.dart';
import 'XmlActionPresets.dart';
import 'actionAddButton.dart';
import 'xmlArrayEditor.dart';


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
          child: _backgroundDeselectArea(
            child: XmlJumpToLineEventWrapper(
              file: widget.root.file!,
              child: Padding(
                padding: const EdgeInsets.only(top: 20, right: 20, bottom: 120, left: 20),
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
                  children: List.generate(actions.length, (index) {
                    var action = actions[index];
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
                          child: SelectableWidget(
                            prop: action,
                            color: getActionPrimaryColor(context, action),
                            borderRadius: BorderRadius.circular(14),
                            onKeyboardAction: (actionType) => onChildKeyboardAction(index, actionType),
                            child: actionEditor
                          ),
                        ),
                        ActionAddButton(parent: widget.root, index: actions.indexOf(action) + 1),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        _makeSyncButton(),
      ],
    );
  }

  Widget _backgroundDeselectArea({ required Widget child }) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              var file = widget.root.file;
              if (file != null)
                selectable.deselectFile(file);
            },
            behavior: HitTestBehavior.translucent,
          ),
        ),
        child,
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
          nameHint: areasManager.fromId(widget.root.file)?.displayName
        ),
      ),
    );
  }
}
