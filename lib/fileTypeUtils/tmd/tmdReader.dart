
import '../utils/ByteDataWrapper.dart';

class TmdEntry {
  final int idSize;
  final String id;
  final int textSize;
  final String text;

  const TmdEntry(this.idSize, this.id, this.textSize, this.text);

  TmdEntry.fromStrings(this.id, this.text)
    : idSize = id.length,
    textSize = text.length;

  int sizeInBytes() {
    return 4 + idSize*2+2 + 4 + textSize*2+2;
  }

  @override
  String toString() {
    return "TmdEntry{\n\tID: $id\n\tText: $text\n}";
  }
}

Future<List<TmdEntry>> readTmdFile(String path) async {
  var reader = await ByteDataWrapper.fromFile(path);
  var entries = <TmdEntry>[];
  int count = reader.readUint32();
  for (int i = 0; i < count; i++) {
    int idSize = reader.readUint32();
    String id = reader.readString(idSize * 2 - 2, encoding: StringEncoding.utf16);
    reader.readUint16(); // 0
    int textSize = reader.readUint32();
    String text = reader.readString(textSize * 2 - 2, encoding: StringEncoding.utf16);
    reader.readUint16(); // 0
    entries.add(TmdEntry(idSize, id, textSize, text));
  }
  return entries;
}
