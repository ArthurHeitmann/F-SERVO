
import '../utils/ByteDataWrapper.dart';
import 'tmdReader.dart';

Future<void> saveTmd(List<TmdEntry> entries, String path) async {
  var totalSize = 4 + entries.fold<int>(0, (int prev, TmdEntry entry) => prev + entry.sizeInBytes());
  var bytes = ByteDataWrapper.allocate(totalSize);
  bytes.writeUint32(entries.length);
  for (var entry in entries) {
    bytes.writeUint32(entry.idSize + 1);
    bytes.writeString0P(entry.id, StringEncoding.utf16);
    bytes.writeUint32(entry.textSize + 1);
    bytes.writeString0P(entry.text, StringEncoding.utf16);
  }

  await bytes.save(path);
}
