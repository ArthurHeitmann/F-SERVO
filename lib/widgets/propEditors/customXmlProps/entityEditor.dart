
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/RowSeparated.dart';
import '../simpleProps/UnderlinePropTextField.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propEditorFactory.dart';
import 'transformsEditor.dart';

class EntityEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlProp prop;

  EntityEditor({super.key, required this.prop, required this.showDetails}) : super(notifier: prop);

  @override
  State<EntityEditor> createState() => _EntityEditorState();
}

class _EntityEditorState extends ChangeNotifierState<EntityEditor> {
  @override
  Widget build(BuildContext context) {
    var paramProp = widget.prop.get("param");
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).formElementBgColor,
          borderRadius: BorderRadius.circular(5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            if (widget.showDetails && widget.prop.get("id") != null)
              makeXmlPropEditor<UnderlinePropTextField>(widget.prop.get("id")!, true),
            makeXmlPropEditor<UnderlinePropTextField>(widget.prop.get("objId")!, widget.showDetails),
            Column(
              children: paramProp
                ?.where((child) => child.tagName == "value" && child.length == 3)
                .map((child) => 
                  RowSeparated(
                    children: [
                      makePropEditor<UnderlinePropTextField>(child[0].value),
                      if (widget.showDetails)
                        makePropEditor<UnderlinePropTextField>(child[1].value),
                      makePropEditor<UnderlinePropTextField>(child[2].value),
                    ],
                  ),
                )
                .toList() ?? [],
            ),
            if (widget.showDetails)
              TransformsEditor<UnderlinePropTextField>(parent: widget.prop),
            if (widget.showDetails)
              ...makeXmlMultiPropEditor<UnderlinePropTextField>(widget.prop, true, (prop) => !_detailsIgnoreList.contains(prop.tagName)),
          ],
        ),
      ),
    );
  }
}

const _detailsIgnoreList = [
  "id", "objId", "location", "scale", "bForwardState"
];
