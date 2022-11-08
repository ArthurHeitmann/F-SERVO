

import 'package:flutter/material.dart';

import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import 'XmlPropEditorFactory.dart';
import 'propEditorFactory.dart';
import 'propTextField.dart';

class XmlPropEditor<T extends PropTextField> extends ChangeNotifierWidget {
  final bool showDetails;
  final bool showTagName;
  final XmlProp prop;

  XmlPropEditor({super.key, required this.prop, required this.showDetails, this.showTagName = true}) : super(notifier: prop);

  @override
  State<XmlPropEditor> createState() => XmlPropEditorState<T>();
}

class XmlPropEditorState<T extends PropTextField> extends ChangeNotifierState<XmlPropEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTagName || widget.prop.value.toString().isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 25),
            child: Row(
              children: [
                if (widget.showTagName)
                  Text(widget.prop.tagName, style: getTheme(context).propInputTextStyle,),
                if (widget.showTagName)
                  const SizedBox(width: 10),
                if (widget.prop.value.toString().isNotEmpty || widget.prop.isEmpty)
                  Flexible(
                    child: makePropEditor<T>(widget.prop.value),
                  ),
              ],
            ),
          ),
        ...makeXmlMultiPropEditor<T>(widget.prop, widget.showDetails)
          .map((child) => Padding(
            padding: const EdgeInsets.only(left: 10),
            child: child,
          )),
      ],
    );
  }
}
