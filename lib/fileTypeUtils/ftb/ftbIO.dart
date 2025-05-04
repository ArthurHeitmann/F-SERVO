import '../utils/ByteDataWrapper.dart';

class FtbFileHeader {
  List<int> magic;
  int texturesCount;
  int unknown;
  int charsCount;
  int texturesOffset;
  int charsOffset;
  int charsOffset2;

  FtbFileHeader(this.magic, this.texturesCount, this.unknown, this.charsCount, this.texturesOffset, this.charsOffset, this.charsOffset2);

  FtbFileHeader.read(ByteDataWrapper bytes) :
    magic = bytes.asUint8List(118),
    texturesCount = bytes.readUint16(),
    unknown = bytes.readUint16(),
    charsCount = bytes.readUint16(),
    texturesOffset = bytes.readUint32(),
    charsOffset = bytes.readUint32(),
    charsOffset2 = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    for (var b in magic)
      bytes.writeUint8(b);
    bytes.writeUint16(texturesCount);
    bytes.writeUint16(unknown);
    bytes.writeUint16(charsCount);
    bytes.writeUint32(texturesOffset);
    bytes.writeUint32(charsOffset);
    bytes.writeUint32(charsOffset2);
  }
}

class FtbFileTexture {
  int index;
  int width;
  int height;
  int u0;
  int u2;
  int u22;

  FtbFileTexture(this.index, this.width, this.height, this.u0, this.u2, this.u22);

  FtbFileTexture.read(ByteDataWrapper bytes) :
    index = bytes.readUint16(),
    width = bytes.readUint16(),
    height = bytes.readUint16(),
    u0 = bytes.readUint16(),
    u2 = bytes.readUint32(),
    u22 = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint16(index);
    bytes.writeUint16(width);
    bytes.writeUint16(height);
    bytes.writeUint16(u0);
    bytes.writeUint32(u2);
    bytes.writeUint32(u22);
  }
}

class FtbFileChar {
  int c;
  int texId;
  int width;
  int height;
  int u;
  int v;

  FtbFileChar(this.c, this.texId, this.width, this.height, this.u, this.v);

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

  void write(ByteDataWrapper bytes) {
    bytes.writeUint16(c);
    bytes.writeUint16(texId);
    bytes.writeUint16(width);
    bytes.writeUint16(height);
    bytes.writeUint16(u);
    bytes.writeUint16(v);
  }
}

class FtbFile {
  late final FtbFileHeader header;
  late final List<FtbFileTexture> textures;
  late final List<FtbFileChar> chars;

  FtbFile(this.header, this.textures, this.chars);

  FtbFile.read(ByteDataWrapper bytes) {
    header = FtbFileHeader.read(bytes);
    bytes.position = header.texturesOffset;
    textures = List.generate(header.texturesCount, (index) => FtbFileTexture.read(bytes));
    bytes.position = header.charsOffset;
    chars = List.generate(header.charsCount, (index) => FtbFileChar.read(bytes));
  }

  static Future<FtbFile> fromFile(String path) async {
    var bytes = await ByteDataWrapper.fromFile(path);
    return FtbFile.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    header.write(bytes);
    bytes.position = header.texturesOffset;
    for (var texture in textures)
      texture.write(bytes);
    bytes.position = header.charsOffset;
    for (var char in chars)
      char.write(bytes);
  }

  Future<void> writeToFile(String path) async {
    var size = header.charsOffset + chars.length * 0xC;
    var bytes = ByteDataWrapper.allocate(size);
    write(bytes);
    await bytes.save(path);
  }
}
