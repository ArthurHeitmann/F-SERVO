
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../../misc/nestedContextMenu.dart';
import '../../misc/smallButton.dart';
import '../simpleProps/XmlPropEditorFactory.dart';

class XmlArrayEditor extends ChangeNotifierWidget {
  final bool showDetails;
  final XmlProp parent;
  final XmlRawPreset childrenPreset;
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

  void addChild([int relIndex = -1]) async {
    assert(widget.sizeIndicator.value is ValueProp);
    assert((widget.sizeIndicator.value as ValueProp).value is num);

    var newProp = await widget.childrenPreset.withCxtV(widget.parent).prop();
    if (newProp == null) {
      showToast("Couldn't create prop");
      return;
    }

    (widget.sizeIndicator.value as ValueProp).value += 1;
    
    int absIndex;
    if (relIndex == -1)
      absIndex = widget.parent.length;
    else
      absIndex = widget.parent.length - getChildProps().length + relIndex;
    widget.parent.insert(absIndex, newProp);
  }

  void deleteChild(int relIndex) {
    assert(widget.sizeIndicator.value is ValueProp);
    assert((widget.sizeIndicator.value as ValueProp).value is num);

    (widget.sizeIndicator.value as ValueProp).value -= 1;
    
    int absIndex = widget.parent.length - getChildProps().length + relIndex;
    widget.parent.removeAt(absIndex);
  }

  Widget childWrapper({ required Widget child, required int index }) {
    return NestedContextMenu(
      clearParent: true,
      buttons: [
          ContextMenuButtonConfig(
            "Delete child",
            icon: Icon(Icons.delete, size: 14,),
            onPressed: () => deleteChild(index),
          ),
      ],
      child: child
    );
  }

  @override
  Widget build(BuildContext context) {
    List<XmlProp> childProps = getChildProps().toList(growable: false);
    List<Widget> children = [];
    for (int i = 0; i < getChildProps().length; i++) {
      children.add(
        childWrapper(
          index: i,
          child: widget.childrenPreset.editor(childProps[i], widget.showDetails),
        )
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...children,
        SmallButton(
          onPressed: addChild,
          constraints: BoxConstraints.tight(const Size(30, 30)),
          child: Icon(Icons.add)
        )
      ],
    );
  }
}
