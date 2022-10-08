
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../misc/smallButton.dart';
import '../simpleProps/XmlPropEditorFactory.dart';

class XmlArrayEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlProp parent;
  final XmlPreset childrenPreset;
  final XmlProp sizeIndicator;
  final String itemsTagName;

  XmlArrayEditor(this.parent, this.childrenPreset, this.sizeIndicator, this.itemsTagName, this.showDetails, {super.key}) : super(notifier: parent);

  @override
  State<XmlArrayEditor> createState() => XmlArrayEditorState();
}

class XmlArrayEditorState extends ChangeNotifierState<XmlArrayEditor> {
  Iterable<XmlProp> getChildProps() {
    return widget.parent.where((child) => child.tagName == widget.itemsTagName);
  }

  void addChild([int index = -1]) {
    assert(widget.sizeIndicator.value is ValueProp);
    assert((widget.sizeIndicator.value as ValueProp).value is num);

    (widget.sizeIndicator.value as ValueProp).value += 1;
    
    if (index == -1)
      index = widget.parent.length - 1;
    // widget.parent.insert(1, widget.childrenPreset.prop()); TODO add back when fixed
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.parent
          .where((child) => child.tagName == widget.itemsTagName)
          .map((child) => widget.childrenPreset.editor(child, widget.showDetails))
          .toList(),
        SmallButton(
          onPressed: addChild,
          constraints: BoxConstraints.tight(const Size(30, 30)),
          child: Icon(Icons.add)
        )
      ],
    );
  }
}
