
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFileContents.dart';
import '../../stateManagement/xmlProp.dart';
import '../propEditors/XmlPropEditor.dart';
import 'XmlActionsEditor.dart';

class XmlFileEditor extends ChangeNotifierWidget {
  late final XmlFileContent fileContent;

  XmlFileEditor({Key? key, required this.fileContent}) : super(key: key, notifier: fileContent);

  @override
  ChangeNotifierState<XmlFileEditor> createState() => _XmlEditorState();
}

class _XmlEditorState extends ChangeNotifierState<XmlFileEditor> {
  @override
  void initState() {
    super.initState();
    widget.fileContent.load();
  }

  @override
  Widget build(BuildContext context) {
    return widget.fileContent.root != null
      ? _makeXmlEditor(widget.fileContent.root!)
      : Text("Loading...");
  }
}

Widget _makeXmlEditor(XmlProp root) {
  if (isActionsXml(root))
    return XmlActionsEditor(root: root);
  else
    return SingleChildScrollView(child: XmlPropEditor(prop: root));
}

bool isActionsXml(XmlProp root) {
  return
    root.any((element) => element.tagName == "name") &&
    root.any((element) => element.tagName == "id") &&
    root.any((element) => element.tagName == "size") &&
    root.any((element) => element.tagName == "action");
}
