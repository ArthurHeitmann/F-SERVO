
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/charNamesXmlWrapper.dart';
import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/xmlProps/xmlProp.dart';
import '../propEditors/otherFileTypes/genericTable/tableEditor.dart';
import '../propEditors/simpleProps/XmlPropEditor.dart';
import 'XmlActionsEditor.dart';

class XmlFileEditor extends ChangeNotifierWidget {
  late final XmlFileData fileContent;

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
      : Column(
        children: const [
          SizedBox(height: 35),
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          ),
        ],
      );
  }
}

Widget _makeXmlEditor(XmlProp root) {
  if (_isActionsXml(root))
    return XmlActionsEditor(root: root);
  if (root is CharNamesXmlProp)
    return TableEditor(config: root);
  return SingleChildScrollView(child: XmlPropEditor(prop: root, showDetails: true,));
}

bool _isActionsXml(XmlProp root) {
  return
    root.any((element) => element.tagName == "name") &&
    root.any((element) => element.tagName == "id") &&
    root.any((element) => element.tagName == "size") &&
    root.any((element) => element.tagName == "action");
}
