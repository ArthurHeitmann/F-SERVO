
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';

class WtaFileHeader {
  static const size = 32;
  String id;
  int version;
  int numTex;
  int offsetTextureOffsets;
  int offsetTextureSizes;
  int offsetTextureFlags;
  int offsetTextureIdx;
  int offsetEnd;

  WtaFileHeader.empty({int? version}) :
    id = "WTB\x00",
    version = version ?? 1,
    numTex = 0,
    offsetTextureOffsets = 0,
    offsetTextureSizes = 0,
    offsetTextureFlags = 0,
    offsetTextureIdx = 0,
    offsetEnd = 0;

  WtaFileHeader.read(ByteDataWrapper bytes) :
    id = bytes.readString(4),
    version = bytes.readInt32(),
    numTex = bytes.readInt32(),
    offsetTextureOffsets = bytes.readUint32(),
    offsetTextureSizes = bytes.readUint32(),
    offsetTextureFlags = bytes.readUint32(),
    offsetTextureIdx = bytes.readUint32(),
    offsetEnd = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeString(id);
    bytes.writeInt32(version);
    bytes.writeInt32(numTex);
    bytes.writeUint32(offsetTextureOffsets);
    bytes.writeUint32(offsetTextureSizes);
    bytes.writeUint32(offsetTextureFlags);
    bytes.writeUint32(offsetTextureIdx);
    bytes.writeUint32(offsetEnd);
  }

  int getFileEnd() {
    if (offsetEnd != 0)
      return offsetEnd;
    else if (offsetTextureIdx != 0)
      return offsetTextureIdx + numTex * 4;
    else
      return offsetTextureFlags + numTex * 4;
  }
}

class WtaFile {
  late WtaFileHeader header;
  late List<int> textureOffsets;
  late List<int> textureSizes;
  late List<int> textureFlags;
  List<int>? textureIdx;

  static const int albedoFlag = 0x26000020;
  static const int noAlbedoFlag = 0x22000020;

  WtaFile(this.header, this.textureOffsets, this.textureSizes, this.textureFlags, this.textureIdx);
  
  WtaFile.read(ByteDataWrapper bytes) {
    header = WtaFileHeader.read(bytes);
    bytes.position = header.offsetTextureOffsets;
    textureOffsets = bytes.readUint32List(header.numTex);
    bytes.position = header.offsetTextureSizes;
    textureSizes = bytes.readUint32List(header.numTex);
    bytes.position = header.offsetTextureFlags;
    textureFlags = bytes.readUint32List(header.numTex);
    if (header.offsetTextureIdx > 0) {
      bytes.position = header.offsetTextureIdx;
      textureIdx = bytes.readUint32List(header.numTex);
    }
  }

  static Future<WtaFile> readFromFile(String path) async {
    var bytes = await ByteDataWrapper.fromFile(path);
    return WtaFile.read(bytes);
  }

  Future<void> writeToFile(String path) async {
    var fileSize = header.getFileEnd();
    fileSize = alignTo(fileSize, 32);
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
    
    if (textureIdx != null) {
      bytes.position = header.offsetTextureIdx;
      for (var i = 0; i < textureIdx!.length; i++)
        bytes.writeUint32(textureIdx![i]);
    }
    
    await bytes.save(path);
  }

  void updateHeader({bool isWtb = false}) {
    header.numTex = textureOffsets.length;
    header.offsetTextureOffsets = 0x20;
    header.offsetTextureSizes = alignTo(header.offsetTextureOffsets + textureOffsets.length * 4, 32);
    header.offsetTextureFlags = alignTo(header.offsetTextureSizes + textureSizes.length * 4, 32);
    if (textureIdx != null)
      header.offsetTextureIdx = alignTo(header.offsetTextureFlags + textureFlags.length * 4, 32);
    else
      header.offsetTextureIdx = 0;
    if (textureIdx == null && !isWtb)
      header.offsetEnd = alignTo(header.getFileEnd(), 32);
    else
      header.offsetEnd = 0;
  }
}
