
import 'dart:typed_data';

import 'package:tuple/tuple.dart';
import 'package:xml/xml.dart';

import '../utils/ByteDataWrapper.dart';
import 'bxmIO.dart';
import '../../fileSystem/FileSystem.dart';

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
  Set<String> uniqueStringsSet = {};
  List<(String, List<int>)> uniqueStrings = [];
  void tryAddString(String string) {
    if (string.isNotEmpty && !uniqueStringsSet.contains(string)) {
      uniqueStrings.add((string, encodeString(string, bxmEncoding)));
      uniqueStringsSet.add(string);
    }
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
    stringToOffset[string.$1] = curOffset;
    curOffset += string.$2.length + 1;
  }

  // calculate data offsets (for strings)
  List<BxmDataOffsets> dataOffsets = [];
  Map<XmlElement, int> nodeToDataIndex = {};
  for (var node in nodes) {
    var dataOffset = BxmDataOffsets(
      stringToOffset[node.name.local] ?? 0xFFFF,
      stringToOffset[_getElementText(node).trim()] ?? 0xFFFF,
    );
    nodeToDataIndex[node] = dataOffsets.length;
    dataOffsets.add(dataOffset);
    for (var attribute in node.attributes) {
      dataOffset = BxmDataOffsets(
        stringToOffset[attribute.name.local] ?? 0xFFFF,
        stringToOffset[attribute.value] ?? 0xFFFF,
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
      var parent = parentMap[xmlNode];
      if (parent != null) {
        var lastChild = parent.childElements.last;
        var lastChildIndex = nodeCombos.indexWhere((combo) => combo.item2 == lastChild);
        nextIndex = lastChildIndex + 1;
      } else {
        nextIndex = nodeInfos.length;
      }
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
      .map((string) => string.$2.length + 1)
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
  for (var string in uniqueStrings) {
    bytes.writeBytes(string.$2);
    bytes.writeUint8(0);
  }
  
  await bytes.save(savePath);
}

Future<void> convertXmlToBxmFile(String xmlPath, String bxmPath) async {
  var xmlStr = await FS.i.readAsString(xmlPath);
  var xml = XmlDocument.parse(xmlStr);
  await xmlToBxm(xml.rootElement, bxmPath);
}
