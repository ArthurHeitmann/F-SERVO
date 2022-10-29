
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../stateManagement/Property.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../utils.dart';
import '../misc/FlexReorderable.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../misc/nestedContextMenu.dart';
import '../propEditors/xmlActions/XmlActionEditorFactory.dart';
import '../propEditors/xmlActions/XmlActionPresets.dart';
import '../propEditors/xmlActions/actionAddButton.dart';
import '../propEditors/xmlActions/xmlArrayEditor.dart';


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
    return SmoothSingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ColumnReorderable(
          crossAxisAlignment: CrossAxisAlignment.start,
          onReorder: (int oldIndex, int newIndex) {
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
                  buttons: [
                    ContextMenuButtonConfig(
                      "Delete Action",
                      icon: const Icon(Icons.delete, size: 14),
                      onPressed: () {
                        (widget.root.get("size")!.value as NumberProp).value -= 1;
                        widget.root.remove(action);
                        action.dispose();
                      }
                    ),
                  ],
                  child: actionEditor
                ),
                ActionAddButton(parent: widget.root, index: actions.indexOf(action) + 1),
              ],
            );
          })
          .toList(),
        ),
      ),
    );
  }
}
