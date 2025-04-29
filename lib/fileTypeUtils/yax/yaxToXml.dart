

import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import '../../fileSystem/FileSystem.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';
import '../xml/xmlExtension.dart';
import 'hashToStringMap.dart';
import 'japToEng.dart';

/*
struct XmlNode {
	uint8 indentation;
	uint32 tagNameHash;
	uint32 stringOffset;
};
*/
class _YaxNode {
  late int indentation;
  late int tagNameHash;
  late int stringOffset;
  late String tagName;
  String? text;
  List<_YaxNode> children = [];

  _YaxNode(ByteDataWrapper bytes) {
    indentation = bytes.readUint8();
    tagNameHash = bytes.readUint32();
    stringOffset = bytes.readUint32();

    tagName = hashToStringMap[tagNameHash] ?? "UNKNOWN";
  }

  XmlElement toXml([ includeAnnotations = true ]) {
    var attributes = <XmlAttribute>[];

    List<XmlNode> childElements = [];
    if (text != null) {
      childElements.add(XmlText(text!));
      if (includeAnnotations && text!.startsWith("0x") && text!.length > 2) {
        var hash = int.parse(text!);
        if (hash != 0) {
          String? hashLookup = hashToStringMap[hash];
          if (hashLookup != null)
            attributes.add(XmlAttribute(XmlName("str"), hashLookup));
        }
      }
      else if (includeAnnotations && !isStringAscii(text!)) {
        String? translation = japToEng[text!];
        if (translation != null)
          attributes.add(XmlAttribute(XmlName("eng"), translation));
      }
    }
    childElements.addAll(children.map((e) => e.toXml(includeAnnotations)));
    
    if (includeAnnotations && tagName == "UNKNOWN")
      attributes.add(XmlAttribute(XmlName("id"), "0x${tagNameHash.toRadixString(16)}"));

    return XmlElement(XmlName(tagName), attributes, childElements);
  }
}

XmlElement yaxToXml(ByteDataWrapper bytes, { includeAnnotations = true }) {
  int nodeCount = bytes.readUint32();
  var nodes = List<_YaxNode>.generate(nodeCount, (index) => _YaxNode(bytes));

  Map<int, String> strings = {};
  while (bytes.position < bytes.length)
    strings[bytes.position] = bytes.readStringZeroTerminated(encoding: StringEncoding.shiftJis);

  for (var node in nodes)
    node.text = strings[node.stringOffset];

  // assemble tree from indents
  List<_YaxNode> root = [];
  for (var node in nodes) {
    if (node.indentation == 0) {
      root.add(node);
      continue;
    }
    var targetIndent = node.indentation - 1;
    var parent = root.last;
    while (parent.indentation != targetIndent)
      parent = parent.children.last;
    parent.children.add(node);
  }

  return XmlElement(XmlName("root"), [], root.map((e) => e.toXml(includeAnnotations)));
}

Future<void> yaxFileToXmlFile(String yaxFilePath) async {
  print("Converting $yaxFilePath to xml");
  messageLog.add("Converting ${path.basename(yaxFilePath)}...");

  var bytes = await ByteDataWrapper.fromFile(yaxFilePath);
  var xml = yaxToXml(bytes);
  var xmlString = xml.toPrettyString();
  // var xmlFile = File(xmlFilePath);
  // await xmlFile.writeAsString('<?xml version="1.0" encoding="utf-8"?>\n');
  // await xmlFile.writeAsString(xmlString, mode: FileMode.append);
  // await xmlFile.writeAsString("\n", mode: FileMode.append);
  xmlString = '<?xml version="1.0" encoding="utf-8"?>\n$xmlString\n';
  var xmlFilePath = "${path.withoutExtension(yaxFilePath)}.xml";
  await FS.i.writeAsString(xmlFilePath, xmlString);
  
  messageLog.add("Converting ${path.basename(yaxFilePath)} done");
}
