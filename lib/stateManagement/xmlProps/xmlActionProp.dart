import '../Property.dart';
import '../undoable.dart';
import 'xmlProp.dart';

class XmlActionProp extends XmlProp {
  late final HexProp code;
  late final StringProp name;
  late final HexProp id;
  late final HexProp attribute;

  XmlActionProp(XmlProp prop) : super(tagId: prop.tagId, tagName: prop.tagName, value: prop.value, file: prop.file, children: prop.toList()) {
    code = this[0].value as HexProp;
    name = this[1].value as StringProp;
    id = this[2].value as HexProp;
    attribute = this[3].value as HexProp;
  }
  @override
  Undoable takeSnapshot() {
    return XmlActionProp(XmlProp(
      tagId: tagId,
      tagName: tagName,
      value: value.takeSnapshot() as Prop,
      file: null,
      children: map((child) => child.takeSnapshot() as XmlProp).toList()
    ));
  }
}
