
import 'package:xml/xml.dart';

import '../../../../../fileTypeUtils/yax/hashToStringMap.dart';
import '../../../../../fileTypeUtils/yax/japToEng.dart';
import '../../../../../utils/utils.dart';
import '../../../../Property.dart';
import '../../../../charNamesXmlWrapper.dart';
import '../../../../listNotifier.dart';
import '../../../../undoable.dart';
import '../../../openFilesManager.dart';
import 'xmlActionProp.dart';

class XmlProp extends ListNotifier<XmlProp> {
  final int tagId;
  final String tagName;
  final Prop value;
  final OpenFileId? file;
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
    value = Prop.fromString(root.childElements.isEmpty ? root.text : "", tagName: root.localName),
    super(root.childElements
      .map((XmlElement child) => XmlProp.fromXml(child, file: file, parentTags: [...parentTags, root.localName]))
      .toList())
  {
    value.addListener(_onValueChange);
  }
  
  factory XmlProp.fromXml(XmlElement root, { OpenFileId? file, required List<String> parentTags })
  {
    var prop = XmlProp._fromXml(root, file: file, parentTags: parentTags);
    if (root.localName == "action")
      return XmlActionProp(prop);
    if (prop.get("name")?.value.toString() == "CharName" && prop.get("text") != null)
      return CharNamesXmlProp(file: file, children: prop.toList());
    
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
    value.dispose();
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
  XmlProp removeAt(int index) {
    var ret = super.removeAt(index);
    _onValueChange();
    return ret;
  }

  @override
  void move(int from, int to) {
    if (from == to) return;
    super.move(from, to);
    _onValueChange();
  }

  @override
  void clear() {
    super.clear();
    _onValueChange();
  }
  
  void _onValueChange() {
    if (file != null) {
      var file = areasManager.fromId(this.file);
      file?.setHasUnsavedChanges(true);
      file?.contentNotifier.notifyListeners();
    }
    undoHistoryManager.onUndoableEvent();
    notifyListeners();
  }

  XmlElement toXml() {
    var element = XmlElement(XmlName(tagName));
    if (tagName == "UNKNOWN")
      element.attributes.add(XmlAttribute(XmlName("id"), "0x${tagId.toRadixString(16)}"));
    
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
  String toString() => "<$tagName>${value.toString()}</$tagName>";

  @override
  Undoable takeSnapshot() {
    var prop = XmlProp(
      tagId: tagId,
      tagName: tagName,
      value: value.takeSnapshot() as Prop,
      file: file,
      children: map((child) => child.takeSnapshot() as XmlProp).toList(),
      parentTags: parentTags,
    );
    prop.overrideUuid(uuid);
    return prop;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var xmlProp = snapshot as XmlProp;
    value.restoreWith(xmlProp.value);
    updateOrReplaceWith(xmlProp.toList(), (child) => child.takeSnapshot() as XmlProp);
  }
}
