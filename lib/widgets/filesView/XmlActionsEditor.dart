
import 'package:flutter/material.dart';

import '../../stateManagement/xmlProps/xmlProp.dart';
import '../../stateManagement/xmlProps/xmlActionProp.dart';
import '../misc/ColumnSeparated.dart';
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

class _XmlActionsEditorState extends XmlArrayEditorState {
  @override
  Widget build(BuildContext context) {
    var actions = getChildProps().toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ColumnSeparated(
        crossAxisAlignment: CrossAxisAlignment.start,
        separatorHeight: 20,
        children: actions
          .map((child) => makeXmlActionEditor(
            action: child as XmlActionProp,
            showDetails: false
          ))
          .toList()
      ),
    );
  }
}
