
import 'dart:io';

import '../utils/ByteDataWrapper.dart';

class SmdEntry {
  final String id;
  final int indexX10;
  final String text;

  const SmdEntry(this.id, this.indexX10, this.text);

  @override
  String toString() {
    return "SmdEntry{\n\tID: $id\n\tText: $text\n}";
  }
}

Future<List<SmdEntry>> readSmdFile(String path) async {
  var reader = await ByteDataWrapper.fromFile(path);
  var entries = <SmdEntry>[];
  int count = reader.readUint32();
  for (int i = 0; i < count; i++) {
    String id = reader.readString(0x80, encoding: StringEncoding.utf16);
    int indexX10 = reader.readUint64();
    String text = reader.readString(0x800, encoding: StringEncoding.utf16);
    var zerosRemover = RegExp("\x00+\$");
    id = id.replaceAll(zerosRemover, "");
    text = text.replaceAll(zerosRemover, "");
    entries.add(SmdEntry(id, indexX10, text));
  }
  return entries;
}
