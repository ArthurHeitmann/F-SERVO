
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:nier_scripts_editor/fileTypeUtils/utils/ByteDataWrapper.dart';

/*
struct HeaderEntry
{
	uint32 type;
	uint32 uncompressedSizeMaybe;
	uint32 offset;
};
 */
class HeaderEntry {
  late int type;
  late int uncompressedSize;
  late int offset;

  HeaderEntry(ByteDataWrapper bytes) {
    type = bytes.readUint32();
    uncompressedSize = bytes.readUint32();
    offset = bytes.readUint32();
  }
}

void extractFile(HeaderEntry meta, int size, ByteDataWrapper bytes, String extractDir, int index) {
  bytes.position = meta.offset;
  bool isCompressed = meta.uncompressedSize > size;
  int paddingEndLength;
  if (isCompressed) {
    int compressedSize = bytes.readUint32();
    paddingEndLength = size - compressedSize - 4;
  }
  else {
    paddingEndLength = (4 - (meta.uncompressedSize % 4)) % 4;
  }
  
  var extractedFile = File(path.join(extractDir, "$index.yax"));
  var fileBytes = bytes.readUint8List(size - paddingEndLength);
  if (isCompressed)
    fileBytes = zlib.decode(fileBytes);
  extractedFile.writeAsBytesSync(fileBytes);
}

List<String> extractPakFile(String pakPath, { bool yaxToXml = false }) {
  var pakFile = File(pakPath);
  ByteDataWrapper bytes = ByteDataWrapper(pakFile.readAsBytesSync().buffer.asByteData());

  bytes.position = 8;
  var firstOffset = bytes.readUint32();
  var fileCount = (firstOffset - 4) ~/ 12;

  bytes.position = 0;
  var headerEntries = List<HeaderEntry>.generate(fileCount, (index) => HeaderEntry(bytes));

  // calculate file sizes from offsets
  List<int> fileSizes = List<int>.generate(fileCount, (index) =>
    index == fileCount - 1
      ? bytes.length - headerEntries[index].offset
      : headerEntries[index + 1].offset - headerEntries[index].offset
  );

  // extract dir is file path --> /pakExtracted/[index]/
  var pakDir = path.dirname(pakPath);
  var extractDir = path.join(pakDir, "pakExtracted", path.basename(pakPath));
  Directory(extractDir).createSync(recursive: true);
  for (int i = 0; i < fileCount; i++) {
    extractFile(headerEntries[i], fileSizes[i], bytes, extractDir, i);
  }

  return List<String>.generate(fileCount, (index) => path.join(extractDir, "$index.yax"));
}
