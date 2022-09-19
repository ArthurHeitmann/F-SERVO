

import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import 'propEditorFactory.dart';

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
            SizedBox(width: 10),
            if (widget.prop.value.toString().isNotEmpty)
              Flexible(
                child: makePropEditor(widget.prop.value),
              ),
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
