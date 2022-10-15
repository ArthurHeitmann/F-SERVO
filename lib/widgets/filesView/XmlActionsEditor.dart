
import 'package:flutter/material.dart';

import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../stateManagement/xmlProps/xmlActionProp.dart';
import '../misc/FlexReorderable.dart';
import '../propEditors/simpleProps/XmlPropEditorFactory.dart';
import '../propEditors/xmlActions/XmlActionEditorFactory.dart';
import '../propEditors/xmlActions/xmlArrayEditor.dart';


class XmlActionsEditor extends XmlArrayEditor {
  final XmlProp root;

  XmlActionsEditor({super.key, required this.root})
    : super(root, XmlPresets.action, root.where((element) => element.tagName == "size").first, "action", false);

  @override
  XmlArrayEditorState createState() => _XmlActionsEditorState();
}

class _XmlActionsEditorState extends XmlArrayEditorState<XmlActionsEditor> {
  @override
  Widget build(BuildContext context) {
    var actions = getChildProps().toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ColumnReorderable(
        crossAxisAlignment: CrossAxisAlignment.start,
        onReorder: (int oldIndex, int newIndex) {
          widget.root.move(oldIndex + firstChildOffset, newIndex + firstChildOffset);
        },
        children: actions.map((action) => makeXmlActionEditor(
          action: action as XmlActionProp,
          showDetails: false,
        ))
        .toList(),
      ),
    );
  }
}
