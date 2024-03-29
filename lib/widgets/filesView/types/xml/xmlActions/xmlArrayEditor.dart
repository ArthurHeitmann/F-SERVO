
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../../../../fileTypeUtils/xml/xmlExtension.dart';
import '../../../../../keyboardEvents/intents.dart';
import '../../../../../stateManagement/Property.dart';
import '../../../../../stateManagement/openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../../../../utils/utils.dart';
import '../../../../misc/ChangeNotifierWidget.dart';
import '../../../../misc/FlexReorderable.dart';
import '../../../../misc/Selectable.dart';
import '../../../../misc/contextMenuBuilder.dart';
import '../../../../misc/nestedContextMenu.dart';
import '../../../../misc/smallButton.dart';
import '../../../../theme/customTheme.dart';
import '../XmlPropEditorFactory.dart';

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

  void incrementChildCount() {
    assert(widget.sizeIndicator.value is ValueProp);
    assert((widget.sizeIndicator.value as ValueProp).value is num);
    (widget.sizeIndicator.value as ValueProp).value += 1;
  }

  void decrementChildCount() {
    assert(widget.sizeIndicator.value is ValueProp);
    assert((widget.sizeIndicator.value as ValueProp).value is num);
    var prop = widget.sizeIndicator.value as ValueProp;
    prop.value -= 1;
    prop.value = max<num>(prop.value, 0);
  }

  void addChild([int relIndex = -1]) async {
    assert(widget.sizeIndicator.value is ValueProp);
    assert((widget.sizeIndicator.value as ValueProp).value is num);

    var newProp = await widget.childrenPreset.withCxtV(widget.parent).prop();
    if (newProp == null) {
      showToast("Couldn't create prop");
      return;
    }

    incrementChildCount();
    
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

    decrementChildCount();
    
    int absIndex = widget.parent.length - getChildProps().length + relIndex;
    var removed = widget.parent.removeAt(absIndex);
    removed.dispose();
  }

  void duplicateChild(int index) {
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

    incrementChildCount();
  }

  void copyChild(int index) {
    var offset = firstChildOffset;
    var ownIndex = offset + index;
    var prop = widget.parent[ownIndex];
    var xml = widget.childrenPreset.duplicateAsXml(prop);
    copyToClipboard(xml.toPrettyString(level: prop.parentTags.length));
  }

  void cutChild(int index) {
    var offset = firstChildOffset;
    var ownIndex = offset + index;
    var xml = widget.parent[ownIndex].toXml();
    copyToClipboard(xml.toPrettyString());
    deleteChild(index);
  }

  void pasteChild(int index) async {
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
      incrementChildCount();
    } catch (e) {
      showToast("Couldn't parse XML");
      rethrow;
    }
  }

  List<ContextMenuConfig?> getContextMenuButtons(int index) {
    return [
      null,
      ContextMenuConfig(
        label: "Duplicate ${widget.childrenPreset.name}",
        shortcutLabel: "Ctrl+D",
        icon: const Icon(Icons.copy_all, size: 14),
        action: () => duplicateChild(index),
      ),
      ContextMenuConfig(
        label: "Copy ${widget.childrenPreset.name} XML",
        shortcutLabel: "Ctrl+C",
        icon: const Icon(Icons.copy, size: 14),
        action: () => copyChild(index),
      ),
      ContextMenuConfig(
        label: "Cut ${widget.childrenPreset.name} XML",
        shortcutLabel: "Ctrl+X",
        icon: const Icon(Icons.cut, size: 14),
        action: () => cutChild(index),
      ),
      ContextMenuConfig(
        label: "Paste ${widget.childrenPreset.name} XML here",
        shortcutLabel: "Ctrl+V",
        icon: const Icon(Icons.paste, size: 14),
        action: () => pasteChild(index),
      ),
      ContextMenuConfig(
        label: "Delete ${widget.childrenPreset.name}",
        shortcutLabel: "Del",
        icon: const Icon(Icons.delete, size: 14),
        action: () => deleteChild(index),
      ),
    ];
  }

  void onChildKeyboardAction(int index, ChildKeyboardActionType actionType) {
    switch (actionType) {
      case ChildKeyboardActionType.duplicate:
        duplicateChild(index);
        break;
      case ChildKeyboardActionType.copy:
        copyChild(index);
        break;
      case ChildKeyboardActionType.cut:
        cutChild(index);
        break;
      case ChildKeyboardActionType.paste:
        pasteChild(index);
        break;
      case ChildKeyboardActionType.delete:
        deleteChild(index);
        break;
    }
  }

  Widget optionalSelectable({ required int index, required XmlProp prop, required Widget child }) {
    if (widget.showDetails)
      return child;
    return SelectableWidget(
      prop: prop,
      padding: 0,
      onKeyboardAction: (actionType) => onChildKeyboardAction(index, actionType),
      child: child,
    );
  }

  Widget childWrapper({ required Key key, required Widget child, required int index, required XmlProp prop }) {
    return NestedContextMenu(
      key: key,
      clearParent: true,
      buttons: getContextMenuButtons(index),
      child: optionalSelectable(
        index: index,
        prop: prop,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<XmlProp> childProps = getChildProps().toList(growable: false);
    List<Widget> children = [];
    for (int i = 0; i < childProps.length; i++) {
      children.add(
        childWrapper(
          key: Key(childProps[i].uuid),
          index: i,
          prop: childProps[i],
          child: widget.childrenPreset.editor(childProps[i], widget.showDetails),
        )
      );
    }
    return NestedContextMenu(
      buttons: [
        ContextMenuConfig(
          label: "Paste ${widget.childrenPreset.name} XML here",
          icon: const Icon(Icons.paste, size: 14),
          action: () async {
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
