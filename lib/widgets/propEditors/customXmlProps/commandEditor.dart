

import 'package:flutter/material.dart';

import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/Selectable.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propEditorFactory.dart';
import 'puidReferenceEditor.dart';

class CommandEditor extends ChangeNotifierWidget {
  final XmlProp prop;
  final bool showDetails;

  CommandEditor({super.key, required this.prop, required this.showDetails}) : super(notifier: prop);

  @override
  State<CommandEditor> createState() => CommandEditorState();
}

class CommandEditorState extends ChangeNotifierState<CommandEditor> {
  static final int _areaCommandCode = crc32("AreaCommand");

  List<XmlProp> _makeAreaCommandPropChildren(XmlProp parent, String tag) {
    return [
      XmlProp(
        file: parent.file,
        tagId: crc32("command"),
        tagName: "command",
        parentTags: [...parent.parentTags, tag],
        children: [
          XmlProp(
            file: parent.file,
            tagId: crc32("label"),
            tagName: "label",
            value: StringProp("commandLabel"),
            parentTags: [...parent.parentTags, tag, "command"],
          )
        ]
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    var isAreaCommand = (widget.prop.get("code")?.value as HexProp?)?.value == _areaCommandCode;
    var command = widget.prop.get("command") ?? widget.prop.get("hit");
    var hitCommand = widget.prop.get("hit");
    var hitoutCommand = widget.prop.get("hitout");
    var args = widget.prop.get("args");

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: optionalSelectable(
        child: Row(
          children: [
            const Text(
              "!",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NestedContextMenu(
                buttons: [
                  if (isAreaCommand && (hitCommand == null || hitoutCommand != null))
                    optionalPropButtonConfig(widget.prop, "hit", () => 6, 
                      () => _makeAreaCommandPropChildren(widget.prop, "hit")),
                  if (isAreaCommand && (hitoutCommand == null || hitCommand != null))
                    optionalPropButtonConfig(widget.prop, "hitout", () => widget.prop.length,
                      () => _makeAreaCommandPropChildren(widget.prop, "hitout")),
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
                      if (command != null)
                        makeCommandEditor(command, isAreaCommand ? "hit" : null)
                      else if (!isAreaCommand)
                        const Text("No command"),
                      if (hitoutCommand != null)
                        makeCommandEditor(hitoutCommand, "hitout"),
                      if (args != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: makeXmlPropEditor(args, widget.showDetails),
                        ),
                    ],
                  ),
                ),
              ),
            )
          ]
        ),
      ),
    );
  }

  Widget makeCommandEditor(XmlProp commParent, String? commLabel) {
    var command = commParent.get("command") ?? commParent;

    return ChangeNotifierBuilder(
      key: Key(commLabel ?? "command"),
      notifiers: [commParent, command],
      builder: (context) {
        var label = command.get("label")?.value;
        var value = command.get("value");
        var args = commParent.get("args");
        return NestedContextMenu(
        buttons: [
          if (label == null)
            optionalValPropButtonConfig(
              command, "label", () => 0,
              () => StringProp("commandLabel")
            ),
          optionalValPropButtonConfig(
            command, "value", () => command.length,
            () => NumberProp(1, true)
          ),
          optionalValPropButtonConfig(
            commParent, "args", () => commParent.length,
            () => StringProp("arg")
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: getTheme(context).textColor!.withOpacity(0.5), thickness: 2,),
            if (commLabel != null)
              Center(
                child: Text(commLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),)
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
          ]
        ),
      );
      },
    );
  }

  Widget optionalSelectable({ required Widget child }) {
    if (widget.showDetails)
      return child;
    if (widget.prop.tagName == "action")
      return child;
    return SelectableWidget(
      prop: widget.prop,
      borderRadius: BorderRadius.circular(5),
      child: child,
    );
  }
}
