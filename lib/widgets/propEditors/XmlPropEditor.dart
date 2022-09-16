

import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/xmlProp.dart';
import 'propTextField.dart';

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
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 200),
                child: PropTextField(prop: widget.prop.value)
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