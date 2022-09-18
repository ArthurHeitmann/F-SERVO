
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

  XmlProp({ required this.file, required this.tagId, String? tagName, Prop? value, String? strValue, List<XmlProp>? children }) :
    tagName = tagName ?? hashToStringMap[tagId] ?? "UNKNOWN",
    value = value ?? Prop.fromString(strValue ?? ""),
    super(children ?? [])
  {
    this.value.addListener(_onValueChange);
  }

  XmlProp._fromXml(XmlElement root, { required this.file }) :
    tagId = crc32(root.localName),
    tagName = root.localName,
    value = Prop.fromString(root.childElements.isEmpty ? root.text : ""),
    super(root.childElements.map((XmlElement child) => XmlProp.fromXml(child, file: file)).toList())
  {
    value.addListener(_onValueChange);
  }
  
  factory XmlProp.fromXml(XmlElement root, { OpenFileData? file })
  {
    var prop = XmlProp._fromXml(root, file: file);
    if (root.localName == "action")
      return XmlActionProp(prop);
    
    return prop;
  }

  XmlProp? get(String tag) {
    var child = where((child) => child.tagName == tag);
    return child.isEmpty ? null : child.first;
  }

  @override
  void dispose() {
    value.removeListener(_onValueChange);
    if (value is ChangeNotifier)
      (value as ChangeNotifier).dispose();
    super.dispose();
  }
  
  void _onValueChange() {
    file?.hasUnsavedChanges = true;
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
      file: null,
      children: map((child) => child.takeSnapshot() as XmlProp).toList()
    );
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var xmlProp = snapshot as XmlProp;
    value.restoreWith(xmlProp.value);
    updateOrReplaceWith(xmlProp.toList(), (child) => child.takeSnapshot() as XmlProp);
  }
}
