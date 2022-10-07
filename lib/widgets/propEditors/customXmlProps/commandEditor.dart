

import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/widgets/propEditors/customXmlProps/puidReferenceEditor.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propEditorFactory.dart';

class CommandEditor extends ChangeNotifierWidget {
  final XmlProp prop;
  final bool showDetails;

  CommandEditor({super.key, required this.prop, required this.showDetails}) : super(notifier: prop);

  @override
  State<CommandEditor> createState() => CommandEditorState();
}

class CommandEditorState extends ChangeNotifierState<CommandEditor> {
  @override
  Widget build(BuildContext context) {
    var command = widget.prop.get("command") ?? widget.prop.get("hit");
    var isHitCommand = command?.tagName == "hit";
    var hitoutCommand = widget.prop.get("hitout");
    var args = widget.prop.get("args");

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        children: [
          Text(
            "!",
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 10),
          Expanded(
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
                  if (command != null)
                    ...makeCommandEditor(command, isHitCommand ? "hit" : null)
                  else
                    Text("No command"),
                  if (hitoutCommand != null)
                    ...makeCommandEditor(hitoutCommand, "hitout"),
                  if (args != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: makeXmlPropEditor(args, widget.showDetails),
                    ),
                ],
              ),
            ),
          )
        ]
      ),
    );
  }

  List<Widget> makeCommandEditor(XmlProp commParent, String? commLabel) {
    var label = commParent.get("command")?.get("label")?.value ?? commParent.get("label")?.value;
    var value = commParent.get("command")?.get("value") ?? commParent.get("value");
    var args = commParent.get("args");

    return [
      Divider(color: getTheme(context).textColor!.withOpacity(0.5), thickness: 2,),
      if (commLabel != null)
        Center(
          child: Text(commLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),)
        ),
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
    ];
  }
}
