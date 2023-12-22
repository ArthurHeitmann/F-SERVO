
import 'package:xml/xml.dart';

extension XmlExtension on XmlNode {
  String toPrettyString({ int? level }) {
    return "${toXmlString(
        pretty: true,
        indent: "\t",
        level: level,
        preserveWhitespace: (node) => node.children.whereType<XmlText>().isNotEmpty
    )}\n";
  }
}
