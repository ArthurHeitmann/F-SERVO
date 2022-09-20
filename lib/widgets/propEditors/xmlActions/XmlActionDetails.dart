

import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../simpleProps/XmlPropEditorFactory.dart';

class XmlActionDetails extends ChangeNotifierWidget {
  final XmlActionProp action;

  XmlActionDetails({super.key, required this.action}) : super(notifier: action);

  @override
  State<XmlActionDetails> createState() => _XmlActionDetailsState();
}

class _XmlActionDetailsState extends ChangeNotifierState<XmlActionDetails> {
  @override
  Widget build(BuildContext context) {
    return makeXmlPropEditor(widget.action);
  }
}
