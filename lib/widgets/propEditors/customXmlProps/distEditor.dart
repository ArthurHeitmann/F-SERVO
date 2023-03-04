
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/XmlPropEditor.dart';
import 'transformsEditor.dart';

class DistEditor extends ChangeNotifierWidget {
  final XmlProp dist;
  final bool showDetails;

  DistEditor({ super.key, required this.dist, required this.showDetails }) : super(notifier: dist);

  @override
  State<DistEditor> createState() => _DistEditorState();
}

class _DistEditorState extends ChangeNotifierState<DistEditor> {
  @override
  Widget build(BuildContext context) {
    return NestedContextMenu(
      buttons: [
        optionalValPropButtonConfig(widget.dist, "position", () => 0, () => VectorProp([0, 0, 0])),
        optionalValPropButtonConfig(
          widget.dist, "rotation", () => getNextInsertIndexAfter(widget.dist, ["position"]),
          () => VectorProp([0, 0, 0])
        ),
        optionalValPropButtonConfig(
          widget.dist, "areaDist", () => getNextInsertIndexAfter(widget.dist, ["rotation", "position"]),
          () => NumberProp(100, true)
        ),
        optionalValPropButtonConfig(
          widget.dist, "resetDist", () => getNextInsertIndexAfter(widget.dist, ["areaDist", "rotation", "position"]),
          () => NumberProp(120, true)
        ),
        optionalValPropButtonConfig(
          widget.dist, "searchDist", () => getNextInsertIndexAfter(widget.dist, ["resetDist", "areaDist", "rotation", "position"]),
          () => NumberProp(30, true)
        ),
        optionalValPropButtonConfig(
          widget.dist, "guardSDist", () => getNextInsertIndexAfter(widget.dist, ["searchDist", "resetDist", "areaDist", "rotation", "position"]),
          () => NumberProp(50, true)
        ),
        optionalValPropButtonConfig(
          widget.dist, "guardLDist", () => getNextInsertIndexAfter(widget.dist, ["guardSDist", "searchDist", "resetDist", "areaDist", "rotation", "position"]),
          () => NumberProp(60, true)
        ),
        optionalValPropButtonConfig(
          widget.dist, "escapeDist", () => getNextInsertIndexAfter(widget.dist, ["guardLDist", "guardSDist", "searchDist", "resetDist", "areaDist", "rotation", "position"]),
          () => NumberProp(70, true)
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text("dist"),
          if (widget.dist.any((e) => e.tagName == "position" || e.tagName == "rotation"))
            TransformsEditor(parent: widget.dist, canBeScaled: false),
          ...widget.dist
            .where((e) => e.tagName != "position" && e.tagName != "rotation")
            .map((e) => Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: XmlPropEditor(prop: e, showDetails: widget.showDetails),
            ))
        ]
      )
    );
  }
}
