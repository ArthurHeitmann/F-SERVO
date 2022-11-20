
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../utils/ByteDataWrapper.dart';

const ZLibEncoder _zLibEncoder = ZLibEncoder();

class _FileEntry {
  int type;
  int uncompressedSize;
  int offset;

  int pakSize;
  List<int> data;
  List<int> compressedData;
  int compressedSize;

  _FileEntry(this.offset, this.type) : uncompressedSize = 0, pakSize = 0, data = [], compressedData = [], compressedSize = -1;

  Future<void> init(File file) async {
    uncompressedSize = await file.length();
    data = await file.readAsBytes();
    var paddingEndLength = (4 - (uncompressedSize % 4)) % 4;
    pakSize = data.length + paddingEndLength;

    if (uncompressedSize > 1024) {
      compressedData = _zLibEncoder.encode(data, level: 1);
      paddingEndLength = (4 - (compressedData.length % 4)) % 4;
      compressedSize = compressedData.length;
      pakSize = 4 + compressedSize + paddingEndLength;
    }
    else {
      compressedData = Uint8List(0);
      compressedSize = -1;
    }
  }

  void writeHeaderEntry(ByteDataWrapper bytes) {
    bytes.writeUint32(type);
    bytes.writeUint32(uncompressedSize);
    bytes.writeUint32(offset);
  }

  void writeFileEntryToFile(ByteDataWrapper bytes) {
    if (compressedData.isNotEmpty) {
      bytes.writeUint32(compressedSize);
      bytes.writeBytes(compressedData);
      var paddingEndLength = (4 - (compressedSize % 4)) % 4;
      bytes.writeBytes(Uint8List(paddingEndLength));
    }
    else {
      bytes.writeBytes(data);
      var paddingEndLength = (4 - (uncompressedSize % 4)) % 4;
      bytes.writeBytes(Uint8List(paddingEndLength));
    }
  }

  int get headerSize => 12;

  int get fileSize {
    if (compressedData.isNotEmpty) {
      return 4 + compressedData.length + (4 - (compressedData.length % 4)) % 4;
    }
    else {
      return data.length + (4 - (data.length % 4)) % 4;
    }
  }
}

Future<void> repackPak(String pakDir) async {
  messageLog.add("Repacking ${path.basename(pakDir)}...");
  
  var infoJsonFile = File(path.join(pakDir, "pakInfo.json"));
  var pakInfo = jsonDecode(await infoJsonFile.readAsString());

  var pakFileName = path.basename(pakDir);
  var pakFile = File(path.join(path.dirname(path.dirname(pakDir)), pakFileName));

  var filesOffset = (pakInfo["files"] as List).length * 12 + 0x4;
  var lastFileOffset = filesOffset;
  var fileEntries = <_FileEntry>[];
  for (var yaxFile in pakInfo["files"]) {
    var yaxF = File(path.join(pakDir, yaxFile["name"]));
    var fileEntry = _FileEntry(lastFileOffset, yaxFile["type"]);
    await fileEntry.init(yaxF);
    fileEntries.add(fileEntry);

    lastFileOffset += fileEntry.pakSize;
  }

  var bytes = ByteDataWrapper(ByteData(lastFileOffset).buffer);
  for (var fileEntry in fileEntries)
    fileEntry.writeHeaderEntry(bytes);
  
  bytes.writeUint32(0);
  for (var fileEntry in fileEntries)
    fileEntry.writeFileEntryToFile(bytes);

  await pakFile.writeAsBytes(bytes.buffer.asUint8List());

  print("Pak file $pakFileName created (${fileEntries.length} file repacked)");
  messageLog.add("Repacking ${path.basename(pakDir)} done");
}
