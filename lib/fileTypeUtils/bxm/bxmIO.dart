import 'package:xml/xml.dart';

import '../utils/ByteDataWrapper.dart';


const bxmEncoding = StringEncoding.shiftJis;

class BxmHeader {
  final String type;
  final int flags;
  final int nodeCount;
  final int dataCount;
  final int dataSize;

  BxmHeader(this.type, this.flags, this.nodeCount, this.dataCount, this.dataSize);

  BxmHeader.read(ByteDataWrapper bytes) :
    type = bytes.readString(4),
    flags = bytes.readInt32(),
    nodeCount = bytes.readUint16(),
    dataCount = bytes.readUint16(),
    dataSize = bytes.readInt32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeString(type);
    bytes.writeInt32(flags);
    bytes.writeUint16(nodeCount);
    bytes.writeUint16(dataCount);
    bytes.writeInt32(dataSize);
  }

  int get size => 4 + 4 + 2 + 2 + 4;
}

class BxmNodeInfo {
  final int childCount;
  int firstChildIndex;
  final int attributeCount;
  final int dataIndex;

  BxmNodeInfo(this.childCount, this.firstChildIndex, this.attributeCount, this.dataIndex);

  BxmNodeInfo.read(ByteDataWrapper bytes) :
    childCount = bytes.readInt16(),
    firstChildIndex = bytes.readUint16(),
    attributeCount = bytes.readInt16(),
    dataIndex = bytes.readInt16();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeInt16(childCount);
    bytes.writeUint16(firstChildIndex);
    bytes.writeInt16(attributeCount);
    bytes.writeInt16(dataIndex);
  }

  int get size => 2 + 2 + 2 + 2;
}

class BxmDataOffsets {
  final int nameOffset;
  final int valueOffset;

  BxmDataOffsets(this.nameOffset, this.valueOffset);

  BxmDataOffsets.read(ByteDataWrapper bytes) :
    nameOffset = bytes.readUint16(),
    valueOffset = bytes.readUint16();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint16(nameOffset);
    bytes.writeUint16(valueOffset);
  }

  int get size => 2 + 2;
}

class BxmXmlNode {
  String name;
  String value;
  Map<String, String> attributes;
  List<BxmXmlNode> children;
  BxmXmlNode? parent;

  int index;
  int firstChildIndex;
  int childCount;

  BxmXmlNode() :
    name = "",
    value = "",
    attributes = {},
    children = [],
    index = -1,
    firstChildIndex = -1,
    childCount = -1;

  XmlElement toXml() {
    XmlElement node = XmlElement(XmlName(name));
    if (value.isNotEmpty) {
      node.children.add(XmlText(value));
    }
    for (String key in attributes.keys) {
      node.setAttribute(key, attributes[key]);
    }
    for (BxmXmlNode child in children) {
      node.children.add(child.toXml());
    }

    return node;
  }
}
