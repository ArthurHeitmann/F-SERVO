
import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';

class WtaFileHeader {
  String id;
  int unknown;
  int numTex;
  int offsetTextureOffsets;
  int offsetTextureSizes;
  int offsetTextureFlags;
  int offsetTextureIdx;
  int offsetTextureInfo;

  WtaFileHeader.read(ByteDataWrapper bytes) :
    id = bytes.readString(4),
    unknown = bytes.readInt32(),
    numTex = bytes.readInt32(),
    offsetTextureOffsets = bytes.readUint32(),
    offsetTextureSizes = bytes.readUint32(),
    offsetTextureFlags = bytes.readUint32(),
    offsetTextureIdx = bytes.readUint32(),
    offsetTextureInfo = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeString(id);
    bytes.writeInt32(unknown);
    bytes.writeInt32(numTex);
    bytes.writeUint32(offsetTextureOffsets);
    bytes.writeUint32(offsetTextureSizes);
    bytes.writeUint32(offsetTextureFlags);
    bytes.writeUint32(offsetTextureIdx);
    bytes.writeUint32(offsetTextureInfo);
  }
}

class WtaFileTextureInfo {
  late int format;
  late List<int> data;

  WtaFileTextureInfo(this.format, this.data);

  WtaFileTextureInfo.read(ByteDataWrapper bytes) :
    format = bytes.readUint32(),
    data = bytes.readUint32List(4);
  
  static Future<WtaFileTextureInfo> fromDds(String ddsPath) async {
    var dds = await ByteDataWrapper.fromFile(ddsPath);
    dds.position = 84;
    var dxt = dds.readString(4);
    dds.position = 112;
    var cube = dds.readUint32();
    if (!const ["DXT1", "DXT3", "DXT5"].contains(dxt))
      messageLog.add("Warning: $ddsPath uses unknown DDS format $dxt. This may not work.");
    var isCube = cube == 0xFE00;
    
    int format = 0;
    List<int> data = [3, isCube ? 4 : 0, 1, 0];
    switch (dxt) {
      case "DXT1":
        format = 71;
        break;
      case "DXT3":
        format = 74;
        break;
      case "DXT5":
        format = 77;
        break;
      default:
        format = 87;
        break;
    }

    return WtaFileTextureInfo(format, data);
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(format);
    for (var d in data)
      bytes.writeUint32(d);
  }
}

class WtaFile {
  late WtaFileHeader header;
  late List<int> textureOffsets;
  late List<int> textureSizes;
  late List<int> textureFlags;
  late List<int> textureIdx;
  late List<WtaFileTextureInfo> textureInfo;

  static const int albedoFlag = 0x26000020;
  static const int noAlbedoFlag = 0x22000020;
  
  WtaFile.read(ByteDataWrapper bytes) {
    header = WtaFileHeader.read(bytes);
    bytes.position = header.offsetTextureOffsets;
    textureOffsets = bytes.readUint32List(header.numTex);
    bytes.position = header.offsetTextureSizes;
    textureSizes = bytes.readUint32List(header.numTex);
    bytes.position = header.offsetTextureFlags;
    textureFlags = bytes.readUint32List(header.numTex);
    bytes.position = header.offsetTextureIdx;
    textureIdx = bytes.readUint32List(header.numTex);
    bytes.position = header.offsetTextureInfo;
    textureInfo = List.generate(
      header.numTex,
      (i) => WtaFileTextureInfo.read(bytes)
    );
  }

  static Future<WtaFile> readFromFile(String path) async {
    var bytes = await ByteDataWrapper.fromFile(path);
    return WtaFile.read(bytes);
  }

  Future<void> writeToFile(String path) async {
    int fileSize;
    if (header.offsetTextureInfo > 0)
      fileSize = header.offsetTextureInfo + textureInfo.length * 0x14;
    else
      fileSize = header.offsetTextureIdx + textureIdx.length * 4;
    var bytes = ByteDataWrapper.allocate(fileSize);
    header.write(bytes);
    
    bytes.position = header.offsetTextureOffsets;
    for (var i = 0; i < textureOffsets.length; i++)
      bytes.writeUint32(textureOffsets[i]);
    
    bytes.position = header.offsetTextureSizes;
    for (var i = 0; i < textureSizes.length; i++)
      bytes.writeUint32(textureSizes[i]);
    
    bytes.position = header.offsetTextureFlags;
    for (var i = 0; i < textureFlags.length; i++)
      bytes.writeUint32(textureFlags[i]);
    
    bytes.position = header.offsetTextureIdx;
    for (var i = 0; i < textureIdx.length; i++)
      bytes.writeUint32(textureIdx[i]);
    
    if (header.offsetTextureInfo > 0) {
      bytes.position = header.offsetTextureInfo;
      for (var i = 0; i < textureInfo.length; i++)
        textureInfo[i].write(bytes);
    }

    await bytes.save(path);
  }

  void updateHeader() {
    header.numTex = textureOffsets.length;
    header.offsetTextureOffsets = 0x20;
    header.offsetTextureSizes = alignTo(header.offsetTextureOffsets + textureOffsets.length * 4, 32);
    header.offsetTextureFlags = alignTo(header.offsetTextureSizes + textureSizes.length * 4, 32);
    header.offsetTextureIdx = alignTo(header.offsetTextureFlags + textureFlags.length * 4, 32);
    header.offsetTextureInfo = alignTo(header.offsetTextureIdx + textureIdx.length * 4, 32);
  }
}
