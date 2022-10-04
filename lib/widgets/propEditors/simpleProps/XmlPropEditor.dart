

import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import 'XmlPropEditorFactory.dart';
import 'propEditorFactory.dart';
import 'propTextField.dart';

class XmlPropEditor<T extends PropTextField> extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlProp prop;

  XmlPropEditor({super.key, required this.prop, required this.showDetails}) : super(notifier: prop);

  @override
  State<XmlPropEditor> createState() => _XmlPropEditorState<T>();
}

class _XmlPropEditorState<T extends PropTextField> extends ChangeNotifierState<XmlPropEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(widget.prop.tagName, style: getTheme(context).propInputTextStyle,),
              SizedBox(width: 10),
              if (widget.prop.value.toString().isNotEmpty)
                Flexible(
                  child: makePropEditor<T>(widget.prop.value),
                ),
            ],
          ),
        ),
        ...makeXmlMultiPropEditor<T>(widget.prop, widget.showDetails)
          .map((w) => Padding(
            padding: const EdgeInsets.only(left: 10),
            child: w,
          )),
      ],
    );
  }
}
