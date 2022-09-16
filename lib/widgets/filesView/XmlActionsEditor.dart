
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/xmlProp.dart';
import '../propEditors/XmlPropEditor.dart';


class XmlActionsEditor extends ChangeNotifierWidget {
  final XmlProp root;

  XmlActionsEditor({super.key, required this.root}) : super(notifier: root);

  @override
  State<XmlActionsEditor> createState() => _XmlActionsEditorState();
}

class _XmlActionsEditorState extends ChangeNotifierState<XmlActionsEditor> {
  @override
  Widget build(BuildContext context) {
    var actions = widget.root.where((element) => element.tagName == "action").toList();
    return ListView.builder(
      itemCount: actions.length,
      itemBuilder: (context, index) => 
        XmlPropEditor(
          key: ValueKey(actions[index]),
          prop: actions[index],
        ),
    );
  }
}
