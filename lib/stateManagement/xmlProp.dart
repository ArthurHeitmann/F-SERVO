
import 'package:xml/xml.dart';

import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../utils.dart';
import 'Property.dart';
import 'nestedNotifier.dart';
import 'undoable.dart';

class XmlProp extends NestedNotifier<XmlProp> {
  final int tagId;
  final String tagName;
  final Prop value;

  XmlProp({ required this.tagId, String? tagName, Prop? value, String? strValue, List<XmlProp>? children }) :
    tagName = tagName ?? hashToStringMap[tagId] ?? "UNKNOWN",
    value = value ?? Prop.fromString(strValue ?? ""),
    super(children ?? [])
  {
    this.value.addListener(notifyListeners);
  }
  
  XmlProp.fromXml(XmlElement root) :
    tagId = crc32(root.localName),
    tagName = root.localName,
    value = Prop.fromString(root.childElements.isEmpty ? root.text : ""),
    super(root.childElements.map((XmlElement child) => XmlProp.fromXml(child)).toList());

  @override
  void dispose() {
    value.removeListener(notifyListeners);
    super.dispose();
  }
  
  @override
  Undoable takeSnapshot() {
    return XmlProp(
      tagId: tagId,
      tagName: tagName,
      value: value.takeSnapshot() as Prop,
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
