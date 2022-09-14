
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFileContents.dart';
import '../../stateManagement/xmlProp.dart';

class XmlActionsEditor extends ChangeNotifierWidget {
  late final XmlFileContent fileContent;

  XmlActionsEditor({Key? key, required this.fileContent}) : super(key: key, notifier: fileContent);

  @override
  ChangeNotifierState<XmlActionsEditor> createState() => _XmlActionsEditorState();
}

class _XmlActionsEditorState extends ChangeNotifierState<XmlActionsEditor> {
  @override
  void initState() {
    super.initState();
    widget.fileContent.load();
  }

  @override
  Widget build(BuildContext context) {
    return widget.fileContent.root != null
      ? XmlPropEditor(prop: widget.fileContent.root!)
      : Text("Loading...");
  }
}

class XmlPropEditor extends ChangeNotifierWidget {
  final XmlProp prop;

  XmlPropEditor({super.key, required this.prop}) : super(notifier: prop);

  @override
  State<XmlPropEditor> createState() => _XmlPropEditorState();
}

class _XmlPropEditorState extends ChangeNotifierState<XmlPropEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(widget.prop.tagName),
            if (widget.prop.value.toString().isNotEmpty)
              Text(": ${widget.prop.value}"),
          ],
        ),
        for (var child in widget.prop)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: XmlPropEditor(prop: child),
          )
      ],
    );
  }
}
