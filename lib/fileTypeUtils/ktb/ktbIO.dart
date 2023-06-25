
import '../utils/ByteDataWrapper.dart';

class KtbEntry {
  final String left;
  final String right;
  final int kerning;

  const KtbEntry(this.left, this.right, this.kerning);

  KtbEntry.read(ByteDataWrapper bytes)
    : left = bytes.readString(2, encoding: StringEncoding.utf16),
      right = bytes.readString(2, encoding: StringEncoding.utf16),
      kerning = bytes.readInt16();

  void write(ByteDataWrapper bytes) {
    bytes.writeString(left, StringEncoding.utf16);
    bytes.writeString(right, StringEncoding.utf16);
    bytes.writeInt32(kerning);
  }
}

class KtbFile {
  final List<KtbEntry> entries;

  const KtbFile(this.entries);

  KtbFile.read(ByteDataWrapper bytes) : entries = <KtbEntry>[] {
    var count = bytes.readInt16();
    for (var i = 0; i < count; i++) {
      entries.add(KtbEntry.read(bytes));
    }
  }

  static Future<KtbFile> fromFile(String path) async {
    var bytes = await ByteDataWrapper.fromFile(path);
    return KtbFile.read(bytes);
  }

  void write(ByteDataWrapper bytes) {
    bytes.writeInt16(entries.length);
    for (var entry in entries) {
      entry.write(bytes);
    }
  }
}


