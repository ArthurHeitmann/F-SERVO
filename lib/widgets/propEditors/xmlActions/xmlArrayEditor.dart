
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../../widgets/theme/customTheme.dart';
import '../../../stateManagement/ChangeNotifierWidget.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils/utils.dart';
import '../../misc/FlexReorderable.dart';
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

class XmlArrayEditorState<T extends XmlArrayEditor> extends ChangeNotifierState<T> {
  int get firstChildOffset {
    for (int i = 0; i < widget.parent.length; i++) {
      if (widget.parent[i].tagName == widget.itemsTagName)
        return i;
    }
    return widget.parent.length;
  }

  Iterable<XmlProp> getChildProps() {
    var firstOffset = firstChildOffset;
    return firstOffset <= 0
      ? widget.parent
      : widget.parent.skip(firstOffset);
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
    var removed = widget.parent.removeAt(absIndex);
    removed.dispose();
  }

  List<ContextMenuButtonConfig?> getContextMenuButtons(int index) {
    return [
      null,
      ContextMenuButtonConfig(
        "Duplicate ${widget.childrenPreset.name}",
        icon: const Icon(Icons.copy_all, size: 14,),
        onPressed: () {
          var offset = firstChildOffset;
          var ownIndex = offset + index;
          widget.parent.insert(
            ownIndex + 1,
            XmlProp.fromXml(
              widget.childrenPreset.duplicateAsXml(widget.parent[ownIndex]),
              parentTags: widget.parent.nextParents(),
              file: widget.parent.file,
            )
          );
        },
      ),
      ContextMenuButtonConfig(
        "Copy ${widget.childrenPreset.name} XML",
        icon: const Icon(Icons.copy, size: 14,),
        onPressed: () {
          var offset = firstChildOffset;
          var ownIndex = offset + index;
          var prop = widget.parent[ownIndex];
          var xml = widget.childrenPreset.duplicateAsXml(prop);
          copyToClipboard(xml.toXmlString(pretty: true, indent: "\t", level: prop.parentTags.length));
        },
      ),
      ContextMenuButtonConfig(
        "Cut ${widget.childrenPreset.name} XML",
        icon: const Icon(Icons.cut, size: 14,),
        onPressed: () {
          var offset = firstChildOffset;
          var ownIndex = offset + index;
          var xml = widget.parent[ownIndex].toXml();
          copyToClipboard(xml.toXmlString(pretty: true));
          deleteChild(index);
        },
      ),
      ContextMenuButtonConfig(
        "Paste ${widget.childrenPreset.name} XML here",
        icon: const Icon(Icons.paste, size: 14,),
        onPressed: () async {
          var offset = firstChildOffset;
          var ownIndex = offset + index;
          var xmlStr = await getClipboardText();
          if (xmlStr == null) {
            showToast("Clipboard is empty");
            return;
          }
          try {
            var xml = XmlDocument.parse(xmlStr);
            var prop = XmlProp.fromXml(
              xml.rootElement,
              parentTags: widget.parent.nextParents(),
              file: widget.parent.file,
            );
            widget.parent.insert(ownIndex + 1, prop);
          } catch (e) {
            showToast("Couldn't parse XML");
          }
        },
      ),
      ContextMenuButtonConfig(
        "Delete ${widget.childrenPreset.name}",
        icon: const Icon(Icons.delete, size: 14,),
        onPressed: () => deleteChild(index),
      ),
    ];
  }

  Widget childWrapper({ required Key key, required Widget child, required int index }) {
    return NestedContextMenu(
      key: key,
      clearParent: true,
      buttons: getContextMenuButtons(index),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            bottom: 0,
            right: 8,
            child: Align(
              alignment: Alignment.centerRight,
              child: FlexDraggableHandle(
                child: Icon(Icons.drag_handle, color: getTheme(context).textColor!.withOpacity(0.5), size: 17,),
              ),
            ),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    List<XmlProp> childProps = getChildProps().toList(growable: false);
    List<Widget> children = [];
    for (int i = 0; i < getChildProps().length; i++) {
      children.add(
        childWrapper(
          key: Key(childProps[i].uuid),
          index: i,
          child: widget.childrenPreset.editor(childProps[i], widget.showDetails),
        )
      );
    }
    return NestedContextMenu(
      buttons: [
        ContextMenuButtonConfig(
          "Paste ${widget.childrenPreset.name} XML here",
          icon: const Icon(Icons.paste, size: 14,),
          onPressed: () async {
            var xmlStr = await getClipboardText();
            if (xmlStr == null) {
              showToast("Clipboard is empty");
              return;
            }
            try {
              var xml = XmlDocument.parse(xmlStr);
              var prop = XmlProp.fromXml(
                xml.rootElement,
                parentTags: widget.parent.nextParents(),
                file: widget.parent.file,
              );
              widget.parent.add(prop);
            } catch (e) {
              showToast("Couldn't parse XML");
            }
          },
        ),
      ],
      child: ColumnReorderable(
        crossAxisAlignment: CrossAxisAlignment.start,
        onReorder: (oldIndex, newIndex) {
          if (oldIndex < 0 || oldIndex >= widget.parent.length || newIndex < 0 || newIndex >= widget.parent.length) {
            print("Invalid reorder: $oldIndex -> $newIndex (length: ${widget.parent.length})");
            return;
          }
          widget.parent.move(oldIndex + firstChildOffset, newIndex + firstChildOffset);
        },
        footer: SmallButton(
          onPressed: addChild,
          constraints: BoxConstraints.tight(const Size(30, 30)),
          child: const Icon(Icons.add)
        ),
        children: [
          ...children,
        ],
      ),
    );
  }
}
