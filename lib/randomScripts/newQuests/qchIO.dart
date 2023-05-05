
import 'dart:io';

import '../../fileTypeUtils/utils/ByteDataWrapper.dart';

class QchHeader {
  static const int size = 20;
  final String magic;
  final double one;
  final int beginOffset;
  final int structSize;
  int count;

  QchHeader(this.magic, this.one, this.beginOffset, this.structSize, this.count);

  QchHeader.read(ByteDataWrapper bytes) :
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

class QchEntry {
  static const int size = 130;
  static const int flagsCount = 126;
  final int questId;
  final List<int> flags;

  const QchEntry(this.questId, this.flags);

  QchEntry.read(ByteDataWrapper bytes) :
    questId = bytes.readUint32(),
    flags = bytes.asUint8List(QchEntry.flagsCount);
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(questId);
    for (var byte in flags)
      bytes.writeUint8(byte);
  }
}

class QchFile {
  late final QchHeader header;
  late final List<QchEntry> entries;

  QchFile(this.header, this.entries);

  QchFile.read(ByteDataWrapper bytes) {
    header = QchHeader.read(bytes);
    entries = List.generate(header.count, (_) => QchEntry.read(bytes));
  }

  static Future<QchFile> readFromFile(File file) async {
    var bytes = await ByteDataWrapper.fromFile(file.path);
    return QchFile.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    header.write(bytes);
    for (var entry in entries)
      entry.write(bytes);
  }

  Future<void> writeToFile(File file) async {
    int totalSize = QchHeader.size + QchEntry.size * entries.length;
    var bytes = ByteDataWrapper.allocate(totalSize);
    write(bytes);
    await file.writeAsBytes(bytes.buffer.asUint8List());
  }
}
