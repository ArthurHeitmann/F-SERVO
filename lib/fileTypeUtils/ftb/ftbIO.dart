import '../utils/ByteDataWrapper.dart';

class FtbFileHeader {
  List<int> start;
  int globalKerning;
  int null0;
  int texturesCount;
  int unknown;
  int charsCount;
  int texturesOffset;
  int charsOffset;
  int charsOffset2;

  FtbFileHeader(this.start, this.globalKerning, this.null0, this.texturesCount, this.unknown, this.charsCount, this.texturesOffset, this.charsOffset, this.charsOffset2);

  FtbFileHeader.read(ByteDataWrapper bytes) :
    start = bytes.readUint8List(114),
    globalKerning = bytes.readInt16(),
    null0 = bytes.readUint16(),
    texturesCount = bytes.readUint16(),
    unknown = bytes.readUint16(),
    charsCount = bytes.readUint16(),
    texturesOffset = bytes.readUint32(),
    charsOffset = bytes.readUint32(),
    charsOffset2 = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    for (var b in start)
      bytes.writeUint8(b);
    bytes.writeInt16(globalKerning);
    bytes.writeUint16(null0);
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
  double widthInverse;
  double heightInverse;

  FtbFileTexture(this.index, this.width, this.height, this.u0) :
    widthInverse = 1 / width,
    heightInverse = 1 / height;

  FtbFileTexture.read(ByteDataWrapper bytes) :
    index = bytes.readUint16(),
    width = bytes.readUint16(),
    height = bytes.readUint16(),
    u0 = bytes.readUint16(),
    widthInverse = bytes.readFloat32(),
    heightInverse = bytes.readFloat32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint16(index);
    bytes.writeUint16(width);
    bytes.writeUint16(height);
    bytes.writeUint16(u0);
    bytes.writeFloat32(widthInverse);
    bytes.writeFloat32(heightInverse);
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
