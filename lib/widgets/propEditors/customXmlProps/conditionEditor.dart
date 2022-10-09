
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propEditorFactory.dart';
import 'puidReferenceEditor.dart';

class ConditionEditor extends ChangeNotifierWidget {
  final XmlProp prop;
  final bool showDetails;

  ConditionEditor({super.key, required this.prop, required this.showDetails}) : super(notifier: prop);

  @override
  State<ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends ChangeNotifierState<ConditionEditor> {
  @override
  Widget build(BuildContext context) {
    var label = widget.prop.get("condition")?.get("state")?.get("label")?.value;
    var value = widget.prop.get("condition")?.get("state")?.get("value");
    var args = widget.prop.get("args");
    var type = widget.prop.get("type");

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        children: [
          Text(
            "?",
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 10),
          Expanded(
            child: NestedContextMenu(
              buttons: [
                if (widget.showDetails)
                  optionalValPropButtonConfig(
                    widget.prop, "type", () => 0,
                    () => NumberProp(0, true)
                  ),
                optionalValPropButtonConfig(
                  widget.prop, "args", () => widget.prop.length,
                  () => NumberProp(0, true)
                ),
              ],
              child: Container(
                decoration: BoxDecoration(
                  color: getTheme(context).formElementBgColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PuidReferenceEditor(prop: widget.prop.get("puid")!, showDetails: widget.showDetails),
                    Divider(color: getTheme(context).textColor!.withOpacity(0.5), thickness: 2,),
                    if (label != null)
                      makePropEditor(label),
                    if (value != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: makeXmlPropEditor(value, widget.showDetails),
                      ),
                    if (args != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: makeXmlPropEditor(args, widget.showDetails),
                      ),
                    if (type != null && widget.showDetails)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: makeXmlPropEditor(type, widget.showDetails),
                      ),
                  ],
                ),
              ),
            ),
          )
        ]
      ),
    );
  }
}


