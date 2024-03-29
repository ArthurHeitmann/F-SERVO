
import 'package:flutter/material.dart';

import '../../../../../stateManagement/Property.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../../../utils/utils.dart';
import '../../../../misc/ChangeNotifierWidget.dart';
import '../../../../misc/nestedContextMenu.dart';
import '../XmlPropEditor.dart';
import 'transformsEditor.dart';

class DistEditor extends ChangeNotifierWidget {
  final XmlProp dist;
  final bool showDetails;
  final bool showTagName;

  DistEditor({
    super.key, required this.dist, required this.showDetails, this.showTagName = true
  }) : super(notifier: dist);

  @override
  State<DistEditor> createState() => _DistEditorState();
}

class _DistEditorState extends ChangeNotifierState<DistEditor> {
  @override
  Widget build(BuildContext context) {
    var fileId = widget.dist.file;
    return NestedContextMenu(
      buttons: [
        optionalValPropButtonConfig(widget.dist, "position", () => 0, () => VectorProp([0, 0, 0], fileId: fileId)),
        optionalValPropButtonConfig(
          widget.dist, "rotation", () => getNextInsertIndexAfter(widget.dist, ["position"]),
          () => VectorProp([0, 0, 0], fileId: fileId)
        ),
        optionalValPropButtonConfig(
          widget.dist, "areaDist", () => getNextInsertIndexAfter(widget.dist, ["rotation", "position"]),
          () => NumberProp(100, true, fileId: fileId)
        ),
        optionalValPropButtonConfig(
          widget.dist, "resetDist", () => getNextInsertIndexAfter(widget.dist, ["areaDist", "rotation", "position"]),
          () => NumberProp(120, true, fileId: fileId)
        ),
        optionalValPropButtonConfig(
          widget.dist, "searchDist", () => getNextInsertIndexAfter(widget.dist, ["resetDist", "areaDist", "rotation", "position"]),
          () => NumberProp(30, true, fileId: fileId)
        ),
        optionalValPropButtonConfig(
          widget.dist, "guardSDist", () => getNextInsertIndexAfter(widget.dist, ["searchDist", "resetDist", "areaDist", "rotation", "position"]),
          () => NumberProp(50, true, fileId: fileId)
        ),
        optionalValPropButtonConfig(
          widget.dist, "guardLDist", () => getNextInsertIndexAfter(widget.dist, ["guardSDist", "searchDist", "resetDist", "areaDist", "rotation", "position"]),
          () => NumberProp(60, true, fileId: fileId)
        ),
        optionalValPropButtonConfig(
          widget.dist, "escapeDist", () => getNextInsertIndexAfter(widget.dist, ["guardLDist", "guardSDist", "searchDist", "resetDist", "areaDist", "rotation", "position"]),
          () => NumberProp(70, true, fileId: fileId)
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTagName)
            const SizedBox(height: 8),
          if (widget.showTagName)
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
