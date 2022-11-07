
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import '../../stateManagement/statusInfo.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';

int _getTagId(XmlElement tag) {
  if (tag.name.local == "UNKNOWN")
    return int.parse(tag.getAttribute("id")!);
  else
    return crc32(tag.name.local);
}

class _XmlNode {
  final int indentation;
  final int tagId;
  final String value;
  int valueOffset;

  _XmlNode(this.indentation, this.tagId, this.valueOffset, this.value);

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(indentation);
    bytes.writeUint32(tagId);
    bytes.writeUint32(valueOffset);
  }
}

ByteDataWrapper xmlToYax(XmlElement root) {
  Set<String> stringSet = {};
  Map<String, int> stringOffsets = {};
  int lastOffset = 0;
  int putStringGetOffset(String string) {
    if (string.isEmpty)
      return 0;
    if (stringSet.contains(string))
      return stringOffsets[string]!;

    stringSet.add(string);
    stringOffsets[string] = lastOffset;
    int retOff = lastOffset;
    var strBytes = encodeString(string, StringEncoding.shiftJis);
    int strByteLength = strBytes.length + 1;
    lastOffset += strByteLength;
    return retOff;
  }

  // read flat tree, create nodes
  List<_XmlNode> nodes = [];
  void addNodeToList(XmlElement node, int indentation) {
    int tagId = _getTagId(node);
    String nodeText = node.children.whereType<XmlText>().map((e) => e.text).join().trim();
    nodes.add(_XmlNode(indentation, tagId, 0, nodeText));
    for (var child in node.childElements) {
      addNodeToList(child, indentation + 1);
    }
  }
  for (var child in root.childElements) {
    addNodeToList(child, 0);
  }

  // make string set
  lastOffset = 4 + nodes.length * 9;
  for (var node in nodes) {
    node.valueOffset = putStringGetOffset(node.value);
  }

  int byteLength = lastOffset;
  ByteDataWrapper bytes = ByteDataWrapper(ByteData(byteLength).buffer);
  bytes.writeUint32(nodes.length);
  for (var node in nodes)
    node.write(bytes);
  for (var string in stringSet)
    bytes.writeString0P(string, StringEncoding.shiftJis);

  return bytes;
}

Future<void> xmlFileToYaxFile(String xmlFilePath) async {
  print("Converting $xmlFilePath to yax");
  messageLog.add("Converting ${path.basename(xmlFilePath)}...");

  var xmlFile = File(xmlFilePath);
  var xmlString = await xmlFile.readAsString();
  var xml = XmlDocument.parse(xmlString);
  var yax = xmlToYax(xml.rootElement);
  var yaxFilePath = "${path.withoutExtension(xmlFilePath)}.yax";
  var yaxFile = File(yaxFilePath);
  await yaxFile.writeAsBytes(yax.buffer.asUint8List());
  
  messageLog.add("Converting ${path.basename(xmlFilePath)} done");
}
