
import 'dart:io';

import '../../fileTypeUtils/utils/ByteDataWrapper.dart';

class ChaHeader {
  final String magic;
  final double one;
  final int beginOffset;
  final int structSize;
  final int count;

  const ChaHeader(this.magic, this.one, this.beginOffset, this.structSize, this.count);

  ChaHeader.read(ByteDataWrapper bytes) :
    magic = bytes.readString(4),
    one = bytes.readFloat32(),
    beginOffset = bytes.readUint32(),
    structSize = bytes.readUint32(),
    count = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeString(magic);
    bytes.writeFloat32(one);
    bytes.writeUint32(beginOffset);
    bytes.writeUint32(structSize);
    bytes.writeUint32(count);
  }
}

/*
struct Entry
{
	ubyte index;
	ubyte chapter;
	ubyte chapter_sub;
	ubyte chapter_sub_sub;
	PlayerType playerType;
	PlayerType2 playerType2;
	uint16 globalPhase<format=hex>;	// like p100, p200, p300, pf31
	char phaseName[34];
	uint32 const0;		// always 0x20e57c
	uint32 const1;		// always 0xfd46184
	uint32 const2;		// always 0xfd456f1
	uint32 const3;		// always 0x20f5f8
	uint32 const4;		// always 0x800
	uint32 const5;		// always 0x35419c
	uint32 const6;		// always 0x0
	uint32 const7;		// always 0x20e5ac
	Printf("%d %d_%d_%d\t%x\t%d\t%d\t%s\n", index, chapter, chapter_sub, chapter_sub_sub, globalPhase, playerType, playerType2, phaseName);
	// Printf("%s\n", phaseName);
};
*/
class ChaEntry {
  final int index;
  final int chapter;
  final int chapterSub;
  final int chapterSubSub;
  final int playerType;
  final int playerType2;
  final int globalPhase;
  final String phaseNameRaw;
  final List<int> unknownBytes;

  const ChaEntry(this.index, this.chapter, this.chapterSub, this.chapterSubSub, this.playerType, this.playerType2, this.globalPhase, this.phaseNameRaw, this.unknownBytes);

  ChaEntry.read(ByteDataWrapper bytes) :
    index = bytes.readUint8(),
    chapter = bytes.readUint8(),
    chapterSub = bytes.readUint8(),
    chapterSubSub = bytes.readUint8(),
    playerType = bytes.readUint32(),
    playerType2 = bytes.readUint32(),
    globalPhase = bytes.readUint16(),
    phaseNameRaw = bytes.readString(34),
    unknownBytes = bytes.asUint8List(32);

  void write(ByteDataWrapper bytes) {
    bytes.writeUint8(index);
    bytes.writeUint8(chapter);
    bytes.writeUint8(chapterSub);
    bytes.writeUint8(chapterSubSub);
    bytes.writeUint32(playerType);
    bytes.writeUint32(playerType2);
    bytes.writeUint16(globalPhase);
    bytes.writeString(phaseNameRaw);
    for (var byte in unknownBytes)
      bytes.writeUint8(byte);
  }

  String get phaseName {
    var nullIndex = phaseNameRaw.indexOf("\x00");
    if (nullIndex == -1)
      return phaseNameRaw;
    return phaseNameRaw.substring(0, nullIndex);
  }
}

class ChaFile {
  late final ChaHeader header;
  late final List<ChaEntry> entries;

  ChaFile(this.header, this.entries);

  ChaFile.read(ByteDataWrapper bytes) {
    header = ChaHeader.read(bytes);
    entries = List.generate(header.count, (_) => ChaEntry.read(bytes));
  }

  static Future<ChaFile> readFromFile(File file) async {
    var bytes = await ByteDataWrapper.fromFile(file.path);
    return ChaFile.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    header.write(bytes);
    for (var entry in entries)
      entry.write(bytes);
  }
}
