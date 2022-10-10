
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/yax/hashToStringMap.dart';
import '../../fileTypeUtils/yax/japToEng.dart';
import '../../utils.dart';
import '../Property.dart';
import '../nestedNotifier.dart';
import '../openFileTypes.dart';
import '../undoable.dart';
import 'xmlActionProp.dart';

class XmlProp extends NestedNotifier<XmlProp> {
  final int tagId;
  final String tagName;
  final Prop value;
  final OpenFileData? file;
  final List<String> parentTags;

  XmlProp({ required this.file, required this.tagId, String? tagName, Prop? value, String? strValue, List<XmlProp>? children, required this.parentTags }) :
    tagName = tagName ?? hashToStringMap[tagId] ?? "UNKNOWN",
    value = value ?? Prop.fromString(strValue ?? "", tagName: tagName),
    super(children ?? [])
  {
    this.value.addListener(_onValueChange);
  }

  XmlProp._fromXml(XmlElement root, { required this.file, required this.parentTags }) :
    tagId = crc32(root.localName),
    tagName = root.localName,
    // TODO check if number is always int
    value = Prop.fromString(root.childElements.isEmpty ? root.text : "", tagName: root.localName),
    super(root.childElements
      .map((XmlElement child) => XmlProp.fromXml(child, file: file, parentTags: [...parentTags, root.localName]))
      .toList())
  {
    value.addListener(_onValueChange);
  }
  
  factory XmlProp.fromXml(XmlElement root, { OpenFileData? file, required List<String> parentTags })
  {
    var prop = XmlProp._fromXml(root, file: file, parentTags: parentTags);
    if (root.localName == "action")
      return XmlActionProp(prop);
    
    return prop;
  }

  XmlProp? get(String tag) {
    var child = where((child) => child.tagName == tag);
    return child.isEmpty ? null : child.first;
  }

  List<XmlProp> getAll(String tag) =>
    where((child) => child.tagName == tag).toList();

  List<String> nextParents([String? next]) => [
    ...parentTags,
    tagName,
    if (next != null)
      next
  ];

  @override
  void dispose() {
    value.removeListener(_onValueChange);
    if (value is ChangeNotifier)
      (value as ChangeNotifier).dispose();
    super.dispose();
  }

  @override
  void add(XmlProp child) {
    super.add(child);
    _onValueChange();
  }

  @override
  void addAll(Iterable<XmlProp> children) {
    super.addAll(children);
    _onValueChange();
  }

  @override
  void insert(int index, XmlProp child) {
    super.insert(index, child);
    _onValueChange();
  }

  @override
  void remove(XmlProp child) {
    super.remove(child);
    _onValueChange();
  }

  @override
  void removeAt(int index) {
    super.removeAt(index);
    _onValueChange();
  }

  @override
  void move(int from, int to) {
    super.move(from, to);
    _onValueChange();
  }

  @override
  void clear() {
    super.clear();
    _onValueChange();
  }
  
  void _onValueChange() {
    file?.hasUnsavedChanges = true;
    file?.contentNotifier.notifyListeners();
    undoHistoryManager.onUndoableEvent();
    notifyListeners();
  }

  XmlElement toXml() {
    var element = XmlElement(XmlName(tagName));
    
    // special attributes
    if (value is StringProp && (value as StringProp).value.isNotEmpty) {
      var translated = japToEng[(value as StringProp).value];
      if (translated != null)
        element.setAttribute("eng", translated);
    }
    else if (value is HexProp && (value as HexProp).isHashed) {
      element.setAttribute("str", (value as HexProp).strVal);
    }
    // text
    String text;
    if (value is StringProp)
      text = (value as StringProp).toString(shouldTransform: false);
    else
      text = value.toString();
    if (text.isNotEmpty)
      element.children.add(XmlText(text));
    // children
    for (var child in this)
      element.children.add(child.toXml());
    
    return element;
  }

  @override
  Undoable takeSnapshot() {
    return XmlProp(
      tagId: tagId,
      tagName: tagName,
      value: value.takeSnapshot() as Prop,
      file: file,
      children: map((child) => child.takeSnapshot() as XmlProp).toList(),
      parentTags: parentTags,
    );
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var xmlProp = snapshot as XmlProp;
    value.restoreWith(xmlProp.value);
    updateOrReplaceWith(xmlProp.toList(), (child) => child.takeSnapshot() as XmlProp);
  }
}
