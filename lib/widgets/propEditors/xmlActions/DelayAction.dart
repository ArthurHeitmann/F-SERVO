

import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../simpleProps/propEditorFactory.dart';
import 'XmlActionEditor.dart';

class DelayActionEditor extends XmlActionEditor {
  DelayActionEditor({ required XmlActionProp action, required super.showDetails}) : super(action: action);

  @override
  XmlActionEditorState createState() => _DelayActionEditorState();
}

class _DelayActionEditorState extends XmlActionEditorState {
  @override
  Widget makeInnerActionBody() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
        const Text("Delay"),
          const SizedBox(width: 10),
          SizedBox(
            width: 50,
            child: makePropEditor(widget.action[4].value)
          ),
        ],
      ),
    );
  }
}
