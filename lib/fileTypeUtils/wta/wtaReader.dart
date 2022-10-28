
/*
struct {
    char    id[4]; //WTB\0
    int32   unknown;
    int32   numTex;
    uint32  offsetTextureOffsets <format=hex>;
    uint32  offsetTextureSizes <format=hex>;
    uint32  offsetTextureFlags <format=hex>;
    uint32  offsetTextureIdx <format=hex>;
    uint32  offsetTextureInfo <format=hex>;
} header;
*/
import 'dart:io';

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
}

class WtaFileTextureInfo {
  int format;
  List<int> data;

  WtaFileTextureInfo.read(ByteDataWrapper bytes) :
    format = bytes.readUint32(),
    data = bytes.readUint32List(4);
}

class WtaFile {
  late final WtaFileHeader header;
  late final List<int> textureOffsets;
  late final List<int> textureSizes;
  late final List<int> textureFlags;
  late final List<int> textureIdx;
  late final List<WtaFileTextureInfo> textureInfo;
  
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
    var bytes = ByteDataWrapper((await File(path).readAsBytes()).buffer);
    return WtaFile.read(bytes);
  }
}
