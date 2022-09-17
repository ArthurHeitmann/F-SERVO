
import 'package:flutter/material.dart';

import '../../stateManagement/xmlProp.dart';
import '../../stateManagement/xmlPropWrappers/xmlActionProp.dart';
import '../misc/ColumnSeparated.dart';
import '../propEditors/xmlActions/XmlActionEditorFactory.dart';
import '../propEditors/xmlActions/xmlArrayEditor.dart';


class XmlActionsEditor extends XmlArrayEditor {
  final XmlProp root;

  XmlActionsEditor({super.key, required this.root})
    : super(root, root.where((element) => element.tagName == "size").first, "action");

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
            key: ValueKey(child),
            action: XmlActionProp(child),
          ))
          .toList()
      ),
    );
  }
}
