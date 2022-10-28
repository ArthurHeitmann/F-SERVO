import '../utils/ByteDataWrapper.dart';

/*
	char magic[118];
	uint16 textures_count;
	uint16 unknown<format=hex>;
	uint16 chars_count;
	uint32 textures_offset<format=hex>;
	uint32 chars_offset<format=hex>;
	uint32 chars_offset2<format=hex>;
*/
class FtbFileHEader {
  List<int> magic;
  int texturesCount;
  int unknown;
  int charsCount;
  int texturesOffset;
  int charsOffset;
  int charsOffset2;

  FtbFileHEader.read(ByteDataWrapper bytes) :
    magic = bytes.readUint8List(118),
    texturesCount = bytes.readUint16(),
    unknown = bytes.readUint16(),
    charsCount = bytes.readUint16(),
    texturesOffset = bytes.readUint32(),
    charsOffset = bytes.readUint32(),
    charsOffset2 = bytes.readUint32();
}

/*
struct Texture
{
	uint16 index;
	uint16 width;
	uint16 height;
	uint16 u_0;
	uint32 u_2<format=hex>;
	uint32 u_22<format=hex>;
};
*/
class FtbFileTexture {
  int index;
  int width;
  int height;
  int u0;
  int u2;
  int u22;

  FtbFileTexture.read(ByteDataWrapper bytes) :
    index = bytes.readUint16(),
    width = bytes.readUint16(),
    height = bytes.readUint16(),
    u0 = bytes.readUint16(),
    u2 = bytes.readUint32(),
    u22 = bytes.readUint32();
}

/*
struct Char
{
	wchar_t c;
	uint16 texId;
	uint16 width;
	uint16 height;
	uint16 u;
	uint16 v;
};
*/
class FtbFileChar {
  int c;
  int texId;
  int width;
  int height;
  int u;
  int v;

  FtbFileChar.read(ByteDataWrapper bytes) :
    c = bytes.readUint16(),
    texId = bytes.readUint16(),
    width = bytes.readUint16(),
    height = bytes.readUint16(),
    u = bytes.readUint16(),
    v = bytes.readUint16();
  
  String get char {
    return String.fromCharCode(c);
  }
}

class FtbFile {
  late final FtbFileHEader header;
  late final List<FtbFileTexture> textures;
  late final List<FtbFileChar> chars;

  FtbFile.read(ByteDataWrapper bytes) {
    header = FtbFileHEader.read(bytes);
    bytes.position = header.texturesOffset;
    textures = List.generate(header.texturesCount, (index) => FtbFileTexture.read(bytes));
    bytes.position = header.charsOffset;
    chars = List.generate(header.charsCount, (index) => FtbFileChar.read(bytes));
  }
}
