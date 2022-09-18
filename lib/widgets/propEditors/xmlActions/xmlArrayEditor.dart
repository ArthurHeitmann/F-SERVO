
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/smallButton.dart';
import '../simpleProps/XmlPropEditorFactory.dart';

class XmlArrayEditor extends ChangeNotifierWidget {
  final XmlProp parent;
  final XmlProp sizeIndicator;
  final String itemsTagName;

  XmlArrayEditor(this.parent, this.sizeIndicator, this.itemsTagName, {super.key}) : super(notifier: parent);

  @override
  State<XmlArrayEditor> createState() => XmlArrayEditorState();
}

class XmlArrayEditorState extends ChangeNotifierState<XmlArrayEditor> {
  Iterable<XmlProp> getChildProps() {
    return widget.parent.where((child) => child.tagName == widget.itemsTagName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.parent
        .where((child) => child.tagName == widget.itemsTagName)
        .map((child) => makeXmlPropEditor(child))
        .toList()
        ..add(SmallButton(child: Icon(Icons.add), onPressed: () {})),
    );
  }
}
