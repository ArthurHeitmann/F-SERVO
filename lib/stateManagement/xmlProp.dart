
import 'package:xml/xml.dart';

import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../utils.dart';
import 'Property.dart';
import 'nestedNotifier.dart';
import 'openFileContents.dart';
import 'undoable.dart';

class XmlProp extends NestedNotifier<XmlProp> {
  final int tagId;
  final String tagName;
  final Prop value;
  final XmlFileContent? file;

  XmlProp({ required this.file, required this.tagId, String? tagName, Prop? value, String? strValue, List<XmlProp>? children }) :
    tagName = tagName ?? hashToStringMap[tagId] ?? "UNKNOWN",
    value = value ?? Prop.fromString(strValue ?? ""),
    super(children ?? [])
  {
    this.value.addListener(_onValueChange);
  }
  
  XmlProp.fromXml(XmlElement root, { required this.file }) :
    tagId = crc32(root.localName),
    tagName = root.localName,
    value = Prop.fromString(root.childElements.isEmpty ? root.text : ""),
    super(root.childElements.map((XmlElement child) => XmlProp.fromXml(child, file: file)).toList())
  {
    value.addListener(_onValueChange);
  }

  @override
  void dispose() {
    value.removeListener(_onValueChange);
    super.dispose();
  }
  
void _onValueChange() {
  file?.id.hasUnsavedChanges = true;
  notifyListeners();
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
