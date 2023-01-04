

import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../simpleProps/XmlPropEditorFactory.dart';

class XmlPropDetails extends ChangeNotifierWidget {
  final XmlProp prop;

  XmlPropDetails({super.key, required this.prop}) : super(notifier: prop);

  @override
  State<XmlPropDetails> createState() => _XmlPropDetailsState();
}

class _XmlPropDetailsState extends ChangeNotifierState<XmlPropDetails> {
  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: makeXmlPropEditor(widget.prop, true)
    );
  }
}
