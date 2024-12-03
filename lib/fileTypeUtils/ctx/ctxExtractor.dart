
import 'dart:io';

import 'package:path/path.dart';

import '../utils/ByteDataWrapper.dart';

Future<List<String>> extractCtx(String path, String extractDir) async {
  var bytes = await ByteDataWrapper.fromFile(path);
  var magic = bytes.readString(4);
  if (magic != "CT2\x00")
    throw Exception("Invalid magic: $magic");
  var fileCount = bytes.readUint32();
  var offsets = bytes.readUint32List(fileCount);

  await Directory(extractDir).create();
  List<String> extractedFiles = [];
  for (int i = 0; i < fileCount; i++) {
    if (offsets[i] == 0)
      continue;
    var filePath = join(extractDir, "${basenameWithoutExtension(path)}_$i.wtb");
    var nextOffset = offsets.skip(i + 1).where((x) => x != 0).firstOrNull ?? bytes.length;
    var size = nextOffset - offsets[i];
    bytes.position = offsets[i];
    var fileBytes = bytes.asUint8List(size);
    File(filePath).writeAsBytesSync(fileBytes);
    extractedFiles.add(filePath);
  }
  return extractedFiles;
}
