
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../misc/ChangeNotifierWidget.dart';
import '../../misc/CustomIcons.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/XmlPropEditorFactory.dart';
import '../simpleProps/propEditorFactory.dart';

class XmlEmgSpawnNodeEditor extends ChangeNotifierWidget {
  final XmlProp prop;
  final bool showDetails;

  XmlEmgSpawnNodeEditor({ super.key, required this.showDetails, required this.prop }) : super(notifier: prop);

  @override
  State<XmlEmgSpawnNodeEditor> createState() => _XmlEmgSpawnNodeEditorState();
}

class _XmlEmgSpawnNodeEditorState extends ChangeNotifierState<XmlEmgSpawnNodeEditor> {
  @override
  Widget build(BuildContext context) {
    var point = widget.prop.get("point")!;
    var radius = widget.prop.get("radius")!;
    var rate = widget.prop.get("rate")!;
    var minDistance = widget.prop.get("minDistance")!;
    var initDirAcquiringMethod = widget.prop.get("initDirAcquiringMethod");
    var initDir = widget.prop.get("initDir");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CustomIcons.sphere, size: 35),
          const SizedBox(width: 5),
          Container(width: 4, color: getTheme(context).editorBackgroundColor,),
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(
                  color: getTheme(context).formElementBgColor!,
                  width: 3,
                )),
              ),
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Transform.rotate(
                        angle: -pi / 4,
                        child: const Icon(Icons.zoom_out_map, size: 16)
                      ),
                      const SizedBox(width: 10),
                      Flexible(child: 
                        Row(
                          children: [
                            Flexible(child: makePropEditor(point.value)),
                          ],
                        )
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(CustomIcons.radius, size: 16),
                      const SizedBox(width: 10),
                      const Text("radius"),
                      const SizedBox(width: 10),
                      makePropEditor(radius.value),
                    ],
                  ),
                  makeXmlPropEditor(rate, widget.showDetails),
                  if (widget.showDetails) ...[
                    makeXmlPropEditor(minDistance, widget.showDetails),
                    if (initDirAcquiringMethod != null)
                      makeXmlPropEditor(initDirAcquiringMethod, widget.showDetails),
                    if (initDir != null)
                      makeXmlPropEditor(initDir, widget.showDetails),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
