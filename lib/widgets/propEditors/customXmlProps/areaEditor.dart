
import 'package:flutter/material.dart';

import '../../../customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../../misc/CustomIcons.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propEditorFactory.dart';
import 'transformsEditor.dart';

final _typeBoxArea = crc32("app::area::BoxArea");
final _typeCylinderArea = crc32("app::area::CylinderArea");
final _typeSphereArea = crc32("app::area::SphereArea");
final _areaIcons = {
  _typeBoxArea: CustomIcons.cube,
  _typeCylinderArea: CustomIcons.cylinder,
  _typeSphereArea: CustomIcons.sphere,
};

class AreaEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlProp prop;

  AreaEditor({super.key, required this.prop, required this.showDetails}) : super(notifier: prop);

  @override
  State<AreaEditor> createState() => _AreaEditorState();
}

class _AreaEditorState extends ChangeNotifierState<AreaEditor> {
  @override
  Widget build(BuildContext context) {
    var type = (widget.prop[0].value as HexProp).value;
    var parent = widget.prop.get("parent");
    var radius = widget.prop.get("radius");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 37,
            height: 37,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: getTheme(context).textColor,
                padding: EdgeInsets.zero,
                side: BorderSide(
                  color: getTheme(context).textColor!.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
              child: Icon(_areaIcons[type]!, size: 35),
            ),
          ),
          SizedBox(width: 5),
          Container(width: 4, color: getTheme(context).editorBackgroundColor,),
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(
                  color: getTheme(context).formElementBgColor!,
                  width: 3,
                )),
              ),
              padding: EdgeInsets.only(left: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (parent != null)
                    makeXmlPropEditor(parent, widget.showDetails),
                  TransformsEditor(
                    parent: widget.prop,
                    canBeRotated: type != _typeSphereArea,
                    canBeScaled: type != _typeSphereArea,
                    itemsCanBeRemoved: false,
                  ),
                  if (radius != null)
                    Row(
                      children: [
                        Icon(CustomIcons.radius, size: 18),
                        SizedBox(width: 10),
                        makePropEditor(radius.value),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
