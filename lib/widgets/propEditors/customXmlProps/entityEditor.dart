
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/UnderlinePropTextField.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import 'paramEditor.dart';
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
      child: NestedContextMenu(
        contextChildren: [
          if (widget.prop.get("id") != null)
            ContextMenuButtonConfig(
              "Copy PUID ref",
              icon: Icon(Icons.content_copy, size: 14,),
              onPressed: () => copyPuidRef("app::EntityLayout", (widget.prop.get("id")!.value as HexProp).value)
            ),
        ],
        child: Container(
          decoration: BoxDecoration(
            color: getTheme(context).formElementBgColor,
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showDetails && widget.prop.get("id") != null)
                makeXmlPropEditor<UnderlinePropTextField>(widget.prop.get("id")!, true),
              makeXmlPropEditor<UnderlinePropTextField>(widget.prop.get("objId")!, widget.showDetails),
              if (!widget.showDetails)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: paramProp
                    ?.where((child) => child.tagName == "value" && child.length == 3)
                    .map((child) => ParamsEditor(prop: child, showDetails: widget.showDetails),
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
      ),
    );
  }
}

const _detailsIgnoreList = [
  "id", "objId", "location", "scale", "bForwardState"
];
