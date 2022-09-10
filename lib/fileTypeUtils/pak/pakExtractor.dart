
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../yax/yaxToXml.dart';
import '../utils/ByteDataWrapper.dart';

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

void _extractPakYax(HeaderEntry meta, int size, ByteDataWrapper bytes, String extractDir, int index) {
  bytes.position = meta.offset;
  bool isCompressed = meta.uncompressedSize > size;
  int readSize;
  if (isCompressed) {
    int compressedSize = bytes.readUint32();
    readSize = compressedSize;
  }
  else {
    int paddingEndLength = (4 - (meta.uncompressedSize % 4)) % 4;
    readSize = size - paddingEndLength;
  }
  
  var extractedFile = File(path.join(extractDir, "$index.yax"));
  var fileBytes = bytes.readUint8List(readSize);
  if (isCompressed)
    fileBytes = zlib.decode(fileBytes);
  extractedFile.writeAsBytesSync(fileBytes);
}

List<String> extractPakFile(String pakPath, { bool yaxToXml = false }) {
  print("Extracting pak files from $pakPath");

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
    _extractPakYax(headerEntries[i], fileSizes[i], bytes, extractDir, i);
  }

  dynamic meta = {
    "files": List.generate(fileCount, (index) => {
      "name": "$index.yax",
      "type": headerEntries[index].type,
    })
  };
  var pakInfoPath = path.join(extractDir, "pakInfo.json");
  File(pakInfoPath).writeAsStringSync(JsonEncoder.withIndent("\t").convert(meta));

  if (yaxToXml) {
    for (int i = 0; i < fileCount; i++) {
      var yaxPath = path.join(extractDir, "$i.yax");
      yaxFileToXmlFile(yaxPath);
    }
  }

  return List<String>.generate(fileCount, (index) => path.join(extractDir, "$index.yax"));
}
