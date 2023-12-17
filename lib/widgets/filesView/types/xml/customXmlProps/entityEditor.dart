
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../../../stateManagement/Property.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../../../utils/utils.dart';
import '../../../../misc/ChangeNotifierWidget.dart';
import '../../../../misc/nestedContextMenu.dart';
import '../../../../propEditors/UnderlinePropTextField.dart';
import '../../../../theme/customTheme.dart';
import '../XmlPropEditorFactory.dart';
import '../xmlActions/xmlArrayEditor.dart';
import '../xmlJumpToLineEventWrapper.dart';
import 'objIdEditor.dart';
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
    bool isLayoutEntity = widget.prop.get("id") != null;
    var paramProp = widget.prop.get("param");
    return optionalIdAnchor(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: contextMenuSetup(
          isLayoutEntity: isLayoutEntity,
          child: Material(
            color: getTheme(context).formElementBgColor,
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showDetails && isLayoutEntity)
                    makeXmlPropEditor<UnderlinePropTextField>(widget.prop.get("id")!, true),
                  ObjIdEditor(
                    objId: widget.prop.get("objId")!,
                    entityId: widget.prop.get("id")?.value as HexProp?,
                  ),
                  if (paramProp != null && !widget.showDetails)
                    XmlArrayEditor(paramProp, XmlPresets.params, paramProp[0], "value", widget.showDetails),
                  if (widget.showDetails && widget.prop.get("location") != null)
                    TransformsEditor<UnderlinePropTextField>(parent: widget.prop),
                  if (widget.showDetails)
                    ...makeXmlMultiPropEditor<UnderlinePropTextField>(widget.prop, true, (prop) => !_detailsIgnoreList.contains(prop.tagName)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget optionalIdAnchor({ required Widget child }) {
    var idProp = widget.prop.get("id");
    if (idProp == null)
      return child;
    return XmlWidgetWithId(
      id: idProp.value as HexProp,
      child: child,
    );
  }

  Widget contextMenuSetup({ required Widget child, required bool isLayoutEntity }) {
    return NestedContextMenu(
      buttons: [
        if (isLayoutEntity) ...[
          ContextMenuButtonConfig(
            "Copy Entity PUID ref",
            icon: const Icon(Icons.content_copy, size: 14,),
            onPressed: () => copyPuidRef("app::EntityLayout", (widget.prop.get("id")!.value as HexProp).value)
          ),
          null,
        ],
        optionalPropButtonConfig(
          widget.prop,
          "param",
          () => getNextInsertIndexBefore(widget.prop, ["delay"], widget.prop.length),
          () async {
            var newProp = await XmlPresets.params.withCxtV(widget.prop).prop();
            var countProp = XmlProp.fromXml(makeXmlElement(name: "count", text: newProp != null ? "0x1" : "0x0"), parentTags: newProp?.nextParents() ?? ["param"]);
            return [
              countProp,
              if (newProp != null) newProp
            ];
          },
        ),
        if (widget.showDetails && isLayoutEntity) ...[
          optionalValPropButtonConfig(
            widget.prop, "flags", () => 1,
            () => HexProp(0, fileId: widget.prop.file),
          ),
          optionalValPropButtonConfig(
            widget.prop, "setFlag", () => widget.prop.indexOf(widget.prop.get("objId")!) + 1,
            () => HexProp(0, fileId: widget.prop.file),
          ),
          optionalValPropButtonConfig(
            widget.prop, "setType", () => getNextInsertIndexAfter(widget.prop, ["setFlag", "objId"]),
            () => NumberProp(0, true, fileId: widget.prop.file),
          ),
          optionalValPropButtonConfig(
            widget.prop, "setRtn", () => getNextInsertIndexAfter(widget.prop, ["setType", "setFlag", "objId"]),
            () => NumberProp(0, true, fileId: widget.prop.file),
          ),
          optionalValPropButtonConfig(
            widget.prop, "alias", () => getNextInsertIndexAfter(widget.prop, ["setRtn", "setType", "setFlag", "objId"]),
            () => StringProp("aliasName", fileId: widget.prop.file),
          ),
          optionalValPropButtonConfig(
            widget.prop, "delay", () => widget.prop.length,
            () => NumberProp(0.0, false, fileId: widget.prop.file),
          ),
        ],
        if (widget.showDetails && !isLayoutEntity) ...[
          optionalPropButtonConfig(
            widget.prop, "levelRange", () => 2,
            () => [
              XmlProp(file: widget.prop.file, tagId: crc32("min"), tagName: "min", value: NumberProp(1, true, fileId: widget.prop.file), parentTags: widget.prop.nextParents("levelRange")),
              XmlProp(file: widget.prop.file, tagId: crc32("max"), tagName: "max", value: NumberProp(1, true, fileId: widget.prop.file), parentTags: widget.prop.nextParents("levelRange")),
            ],
          ),
          optionalValPropButtonConfig(
            widget.prop, "setType", () => getNextInsertIndexAfter(widget.prop, ["levelRange", "rate"]),
            () => NumberProp(0, true, fileId: widget.prop.file),
          ),
          optionalValPropButtonConfig(
            widget.prop, "setRtn", () => getNextInsertIndexAfter(widget.prop, ["setType", "levelRange", "rate"]),
            () => NumberProp(0, true, fileId: widget.prop.file),
          ),
          optionalValPropButtonConfig(
            widget.prop, "setFlag", () => getNextInsertIndexAfter(widget.prop, ["setRtn", "setType", "levelRange", "rate"]),
            () => HexProp(0, fileId: widget.prop.file),
          ),
          optionalValPropButtonConfig(
            widget.prop, "type2type", () => getNextInsertIndexAfter(widget.prop, ["setFlag", "setRtn", "setType", "levelRange", "rate"]),
            () => NumberProp(1, true, fileId: widget.prop.file),
          ),
          optionalPropButtonConfig(
            widget.prop, "type2", () => getNextInsertIndexAfter(widget.prop, ["type2type", "setFlag", "setRtn", "setType", "levelRange", "rate"]),
            () => [
              XmlProp(file: widget.prop.file, tagId: crc32("setRtn"), tagName: "setRtn", value: NumberProp(25, true, fileId: widget.prop.file), parentTags: widget.prop.nextParents(("type2"))),
              XmlProp(file: widget.prop.file, tagId: crc32("setType"), tagName: "setType", value: NumberProp(2, true, fileId: widget.prop.file), parentTags: widget.prop.nextParents(("type2"))),
              XmlProp(file: widget.prop.file, tagId: crc32("setFlag"), tagName: "setFlag", value: HexProp(0x10000000, fileId: widget.prop.file), parentTags: widget.prop.nextParents(("type2"))),
            ],
          ),
        ],
      ],
      child: child
    );
  }
}

const _detailsIgnoreList = [
  "id", "objId", "location", "scale", "bForwardState"
];
