
import 'dart:io';
import 'dart:typed_data';

import '../utils/ByteDataWrapper.dart';
import 'smdReader.dart';

Future<void> saveSmd(List<SmdEntry> entries, String path) async {
  var totalSize = 4 + entries.length * 0x888;
  var bytes = ByteDataWrapper.allocate(totalSize);
  bytes.writeUint32(entries.length);
  for (var entry in entries) {
    var id = entry.id.padRight(0x40, '\x00');
    var text = entry.text.padRight(0x400, '\x00');
    bytes.writeString(id, StringEncoding.utf16);
    bytes.writeUint64(entry.indexX10);
    bytes.writeString(text, StringEncoding.utf16);
  }

  var file = File(path);
  await file.writeAsBytes(bytes.buffer.asUint8List());
}
