
import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../utils/ByteDataWrapper.dart';
import 'bxmIO.dart';

const _errorString = "ERROR";

XmlElement parseBxm(ByteDataWrapper bytes) {
  bytes.endian = Endian.big;

  var header = BxmHeader.read(bytes);

  List<BxmNodeInfo> nodeInfos = List.generate(
    header.nodeCount,
    (i) => BxmNodeInfo.read(bytes)
  );

  List<BxmDataOffsets> dataOffsets = List.generate(
    header.dataCount,
    (i) => BxmDataOffsets.read(bytes)
  );

  var stringsOffsets = 0x10 + 8*header.nodeCount + 4*header.dataCount;

  List<BxmXmlNode> nodes = [];
  for (var i = 0; i < nodeInfos.length; i++) {
    var nodeInfo = nodeInfos[i];
    var node = BxmXmlNode();
    node.index = i;
    node.firstChildIndex = nodeInfo.firstChildIndex;
    node.childCount = nodeInfo.childCount;

    var nodeNameOffset = dataOffsets[nodeInfo.dataIndex].nameOffset;
    if (nodeNameOffset != 0xFFFF) {
      bytes.position = stringsOffsets + nodeNameOffset;
      node.name = bytes.readStringZeroTerminated(encoding: bxmEncoding, errorFallback: _errorString);
    }
    var nodeValueOffset = dataOffsets[nodeInfo.dataIndex].valueOffset;
    if (nodeValueOffset != 0xFFFF) {
      bytes.position = stringsOffsets + nodeValueOffset;
      node.value = bytes.readStringZeroTerminated(encoding: bxmEncoding, errorFallback: _errorString);
    }

    node.attributes = {};
    for (var i = 0; i < nodeInfo.attributeCount; i++) {
      var attributeName = "";
      var attributeValue = "";
      var attributeNameOffset = dataOffsets[nodeInfo.dataIndex + 1 + i].nameOffset;
      if (attributeNameOffset != 0xFFFF) {
        bytes.position = stringsOffsets + attributeNameOffset;
        attributeName = bytes.readStringZeroTerminated(encoding: bxmEncoding, errorFallback: _errorString);
      }
      var attributeValueOffset = dataOffsets[nodeInfo.dataIndex + 1 + i].valueOffset;
      if (attributeValueOffset != 0xFFFF) {
        bytes.position = stringsOffsets + attributeValueOffset;
        attributeValue = bytes.readStringZeroTerminated(encoding: bxmEncoding, errorFallback: _errorString);
      }
      node.attributes[attributeName] = attributeValue;
    }

    nodes.add(node);
  }

  List<BxmXmlNode> getNodeNextSiblings(BxmXmlNode node) {
    return nodes.sublist(node.index + 1, node.firstChildIndex);
  }

  List<BxmXmlNode> getNodeChildren(BxmXmlNode node) {
    if (node.childCount == 0)
      return [];
    var firstChild = nodes[node.firstChildIndex];
    var otherChildren = getNodeNextSiblings(firstChild);
    return [firstChild, ...otherChildren];
  }

  for (var node in nodes) {
    node.children = getNodeChildren(node);
    for (var child in node.children) {
      child.parent = node;
    }
  }

  return nodes[0].toXml();
}

Future<XmlElement> parseBxmFile(String path) async {
  var bytes = await ByteDataWrapper.fromFile(path);
  return parseBxm(bytes);
}

Future<void> convertBxmFileToXml(String bxmPath, String xmlPath) async {
  var root = await parseBxmFile(bxmPath);
  var doc = XmlDocument();
  doc.children.add(XmlDeclaration([XmlAttribute(XmlName("version"), "1.0"), XmlAttribute(XmlName("encoding"), "utf-8")]));
  doc.children.add(root);
  var xmlStr = "${doc.toXmlString(pretty: true, indent: "\t")}\n";
  await File(xmlPath).writeAsString(xmlStr);
}
