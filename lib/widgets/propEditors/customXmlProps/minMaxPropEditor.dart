
import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/ChangeNotifierWidget.dart';
import '../../misc/nestedContextMenu.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';

class MinMaxPropEditor<T extends PropTextField> extends ChangeNotifierWidget {
  final XmlProp prop;

  MinMaxPropEditor({ super.key, required this.prop }) : super(notifier: prop);

  @override
  State<MinMaxPropEditor<T>> createState() => _MinMaxPropEditorState<T>();
}

class _MinMaxPropEditorState<T extends PropTextField> extends ChangeNotifierState<MinMaxPropEditor<T>> {
  @override
  Widget build(BuildContext context) {
    var minProp = widget.prop.get("min");
    var maxProp = widget.prop.get("max");
    return Align(
      alignment: Alignment.centerLeft,
      child: NestedContextMenu(
        buttons: [
          optionalValPropButtonConfig(
            widget.prop, "min", () => 0,
            () => NumberProp(1, false, fileId: widget.prop.file)
          ),
          optionalValPropButtonConfig(
            widget.prop, "max", () => widget.prop.length,
            () => NumberProp(2, false, fileId: widget.prop.file)
          ),
        ],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                widget.prop.tagName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (minProp != null)
              makePropEditor<T>(minProp.value)
            else
              const SizedBox(width: 50),
            const Text("  –  "),
            if (maxProp != null)
              makePropEditor<T>(maxProp.value),
          ],
        ),
      ),
    );
  }
}
