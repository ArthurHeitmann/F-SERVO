

import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/openFilesManager.dart';
import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../utils/utils.dart';
import '../../filesView/xmlJumpToLineEventWrapper.dart';
import '../../misc/FlexReorderable.dart';
import '../../misc/Selectable.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/DoubleClickablePropTextField.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propTextField.dart';

final Set<String> ignoreTagNames = {
  "code",
  "name",
  "id",
  "attribute",
};

final Set<int> spawningActionCodes = {
  crc32("EntityLayoutAction"),
  crc32("EntityLayoutArea"),
  crc32("EnemySetAction"),
  crc32("EnemySetArea"),
  crc32("EnemyGenerator"),
};

class XmlActionEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlActionProp action;

  XmlActionEditor({ Key? key, required this.action, required this.showDetails })
    : super(key: key ?? Key(action.uuid), notifiers: [action, action.attribute]);

  @override
  State<XmlActionEditor> createState() => XmlActionEditorState();
}

class XmlActionEditorState<T extends XmlActionEditor> extends ChangeNotifierState<T> {
  @override
  Widget build(BuildContext context) {
    return XmlWidgetWithId(
      id: widget.action.id,
      child: SelectableWidget<XmlActionProp>(
        area: areasManager.getAreaOfFile(widget.action.file!),
        data: widget.action,
        color: getActionPrimaryColor(context).withOpacity(0.5),
        child: NestedContextMenu(
          buttons: [
            ContextMenuButtonConfig(
              "Copy Action PUID ref",
              icon: const Icon(Icons.content_copy, size: 14,),
              onPressed: () => copyPuidRef("hap::Action", widget.action.id.value)
            ),
          ],
          child: SizedBox(
            width: 450,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                makeActionHeader(context),
                makeActionBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color getActionPrimaryColor(BuildContext context) {
    Color color;
    if (widget.action.attribute.value & 0x8 != 0)
      color = getTheme(context).actionTypeBlockingAccent!;
    else if (spawningActionCodes.contains(widget.action.code.value))
      color = getTheme(context).actionTypeEntityAccent!;
    else
      color = getTheme(context).actionTypeDefaultAccent!;
    
    if (widget.action.attribute.value & 0x2 != 0)
      color = Color.fromRGBO(color.red ~/ 2, color.green ~/ 2, color.blue ~/ 2, 1);
    
    return color;
  }

  Widget makeActionHeader(BuildContext context) {
    return Material(
      // decoration: BoxDecoration(
        color: getActionPrimaryColor(context),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(getTheme(context).actionBorderRadius!), topRight: Radius.circular(getTheme(context).actionBorderRadius!)),
      // ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Colors.white,
            selectionColor: Colors.black.withOpacity(0.5),
            selectionHandleColor: Colors.white,
          ),
          extensions: [getTheme(context).copyWith(
            propInputTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: "FiraCode",
            overflow: TextOverflow.ellipsis,
          )
          )]
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              const SizedBox(width: 10, height: 10),  // placeholder for future icon or button
              Expanded(
                child: Column(
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14
                        ),
                        text: widget.action.code.strVal ?? "UNKNOWN ${widget.action.code.value}"
                      )
                    ),
                    const SizedBox(height: 2),
                    PropTextField.make<DoubleClickablePropTextField>(prop: widget.action.name),
                  ],
                ),
              ),
              ...getRightHeaderButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> getRightHeaderButtons(BuildContext context) {
    return [
      FlexDraggableHandle(
        child: Icon(Icons.drag_handle, color: getTheme(context).textColor!.withOpacity(0.5),),
      )
    ];
  }

  Widget makeActionBody() {
    return Container(
      decoration: BoxDecoration(
        color: getTheme(context).actionBgColor,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(getTheme(context).actionBorderRadius!), bottomRight: Radius.circular(getTheme(context).actionBorderRadius!)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: makeInnerActionBody(),
      ),
    );
  }

  Widget makeInnerActionBody() {
    return Column(
      children: makeXmlMultiPropEditor(
        widget.action,
        widget.showDetails,
        (prop) => !ignoreTagNames.contains(prop.tagName)
      ),
    );
  }
}
