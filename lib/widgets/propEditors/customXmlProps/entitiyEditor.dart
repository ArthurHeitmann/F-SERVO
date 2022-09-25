

import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
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
    var levelParams = paramProp?.where((prop) => prop.isNotEmpty && (prop[0].value as StringProp).value.contains("Lv"));
    var nameTagParam = paramProp?.find((prop) => prop.isNotEmpty && (prop[0].value as StringProp).value == "NameTag");
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
            if (widget.showDetails)
              makeXmlPropEditor(widget.prop.get("id")!, true),
            makeXmlPropEditor(widget.prop.get("objId")!, widget.showDetails),
            if (!widget.showDetails && levelParams != null && levelParams.isNotEmpty)
              for (var levelParam in levelParams)
                Row(
                  children: levelParam.map((prop) => makePropEditor(prop.value)).toList(),
                ),
            if (!widget.showDetails && nameTagParam != null)
              Row(
                children: nameTagParam.map((prop) => makePropEditor(prop.value)).toList(),
              ),
            if (widget.showDetails)
              TransformsEditor(parent: widget.prop),
            if (widget.showDetails)
              ...makeXmlMultiPropEditor(widget.prop, true, (prop) => !_detailsIgnoreList.contains(prop.tagName)),
          ],
        ),
      ),
    );
  }
}

const _detailsIgnoreList = [
  "id", "objId", "location", "scale", "bForwardState"
];
