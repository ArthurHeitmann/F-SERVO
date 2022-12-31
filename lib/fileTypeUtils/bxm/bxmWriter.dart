
import 'dart:io';
import 'dart:typed_data';

import 'package:tuple/tuple.dart';
import 'package:xml/xml.dart';

import '../utils/ByteDataWrapper.dart';
import 'bxmIO.dart';

String _getElementText(XmlElement element) {
  var textNodes = element.children.whereType<XmlText>();
  return textNodes.join();
}

Future<void> xmlToBxm(XmlElement root, String savePath) async {
  // flatten tree
  List<XmlElement> nodes = [];
  void getNodes(XmlElement node) {
    nodes.add(node);
    for (var child in node.childElements)
      getNodes(child);
  }
  getNodes(root);

  // gather all unique strings in tag names, tag value, attribute names and attribute values
  List<String> uniqueStrings = [];
  void tryAddString(String string) {
    if (string.isNotEmpty && !uniqueStrings.contains(string))
      uniqueStrings.add(string);
  }
  for (var node in nodes) {
    tryAddString(node.name.local);
    for (var attribute in node.attributes) {
      tryAddString(attribute.name.local);
      tryAddString(attribute.value);
    }
    tryAddString(_getElementText(node).trim());
  }

  // calculate string offsets
  Map<String, int> stringToOffset = {};
  int curOffset = 0;
  for (var string in uniqueStrings) {
    stringToOffset[string] = curOffset;
    curOffset += string.length + 1;
  }

  // calculate data offsets (for strings)
  List<BxmDataOffsets> dataOffsets = [];
  Map<XmlElement, int> nodeToDataIndex = {};
  for (var node in nodes) {
    var dataOffset = BxmDataOffsets(
      stringToOffset[node.name.local] ?? -1,
      stringToOffset[_getElementText(node).trim()] ?? -1,
    );
    nodeToDataIndex[node] = dataOffsets.length;
    dataOffsets.add(dataOffset);
    for (var attribute in node.attributes) {
      dataOffset = BxmDataOffsets(
        stringToOffset[attribute.name.local] ?? -1,
        stringToOffset[attribute.value] ?? -1,
      );
      dataOffsets.add(dataOffset);
    }
  }

  // make node infos
  Map<BxmNodeInfo, XmlElement> nodeInfoToXmlNode = {};
  List<Tuple2<BxmNodeInfo, XmlElement>> nodeCombos = [];
  Map<XmlElement, XmlElement> parentMap = {
    for (var parent in nodes)
      for (var child in parent.childElements)
        child: parent
  };
  BxmNodeInfo nodeToNodeInfo(XmlElement node) {
    var nodeInfo = BxmNodeInfo(
      node.childElements.length,
      -1,
      node.attributes.length,
      nodeToDataIndex[node]!,
    );
    nodeInfoToXmlNode[nodeInfo] = node;
    nodeCombos.add(Tuple2(nodeInfo, node));
    return nodeInfo;
  }

  // xml nodes to node infos in correct order
  List<BxmNodeInfo> nodeInfos = [];
  void addNodeChildrenToInfos(XmlElement node) {
    for (var child in node.childElements)
      nodeInfos.add(nodeToNodeInfo(child));
    for (var child in node.childElements)
      addNodeChildrenToInfos(child);
  }
  nodeInfos.add(nodeToNodeInfo(root));
  addNodeChildrenToInfos(root);
  // set first child index / next sibling index
  for (var nodeInfo in nodeInfos) {
    int nextIndex = -1;
    if (nodeInfo.childCount > 0) {
      var firstChild = nodeInfoToXmlNode[nodeInfo]!.childElements.first;
      // index of first child in node
      nextIndex = nodeCombos.indexWhere((combo) => combo.item2 == firstChild);
    } else {
      var xmlNode = nodeInfoToXmlNode[nodeInfo]!;
      var parent = parentMap[xmlNode]!;
      var lastChild = parent.childElements.last;
      var lastChildIndex = nodeCombos.indexWhere((combo) => combo.item2 == lastChild);
      nextIndex = lastChildIndex + 1;
    }
    nodeInfo.firstChildIndex = nextIndex;
  }

  // write file
  var header = BxmHeader(
    "XML\x00",
    0,
    nodeInfos.length,
    dataOffsets.length,
    uniqueStrings
      .map((string) => string.length + 1)
      .fold(0, (a, b) => a + b),
  );

  var fileSize = (
    header.size +
    nodeInfos.fold<int>(0, (a, b) => a + b.size) +
    dataOffsets.fold<int>(0, (a, b) => a + b.size) +
    header.dataSize
  );
  var bytes = ByteDataWrapper.allocate(fileSize, endian: Endian.big);
  header.write(bytes);
  for (var nodeInfo in nodeInfos)
    nodeInfo.write(bytes);
  for (var dataOffset in dataOffsets)
    dataOffset.write(bytes);
  for (var string in uniqueStrings)
    bytes.writeString0P(string);
  
  await File(savePath).writeAsBytes(bytes.buffer.asUint8List());
}

Future<void> convertXmlToBxmFile(String xmlPath, String bxmPath) async {
  var xmlStr = await File(xmlPath).readAsString();
  var xml = XmlDocument.parse(xmlStr);
  await xmlToBxm(xml.rootElement, bxmPath);
}
