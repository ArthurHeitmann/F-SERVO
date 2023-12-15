
import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/ChangeNotifierWidget.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/XmlPropEditorFactory.dart';

abstract class XmlActionInnerEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlActionProp action;
  
  XmlActionInnerEditor({ super.key, required this.action, required this.showDetails })
    : super(notifier: action);
}

abstract class XmlActionInnerEditorState<T extends XmlActionInnerEditor> extends ChangeNotifierState<T> {
   Widget makeGroupWrapperSingle(String title, Iterable<XmlProp> props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(title, style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        for (var prop in props)
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: makeXmlPropEditor(prop, widget.showDetails),
          )
      ],
    );
  }
  Widget makeGroupWrapperMulti(String title, Iterable<XmlProp> props) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(title, style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        ...props.map((prop) => makeXmlMultiPropEditor(prop, widget.showDetails)
          .map((child) => Padding(
            key: child.key != null ? ValueKey(child.key) : null,
            padding: const EdgeInsets.only(left: 10),
            child: child,
          ))
        ).expand((e) => e),
      ],
    );
  }
  Widget makeGroupWrapperCustom(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 25),
          child: Row(
            children: [
              Text(title, style: getTheme(context).propInputTextStyle,),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: child,
        ),
      ],
    );
  }
  Widget makeSeparator() {
    return const Divider(
      height: 20,
      thickness: 1,
      indent: 10,
      endIndent: 10,
    );
  }
}
