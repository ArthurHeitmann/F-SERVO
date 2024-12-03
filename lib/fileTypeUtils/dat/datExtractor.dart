
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../pak/pakExtractor.dart';
import '../utils/ByteDataWrapper.dart';

/*
struct {
    char    id[4];
    uint32  fileNumber;
    uint32  fileOffsetsOffset <format=hex>;
    uint32  fileExtensionsOffset <format=hex>;
    uint32  fileNamesOffset <format=hex>;
    uint32  fileSizesOffset <format=hex>;
    uint32  hashMapOffset <format=hex>;
} header;
*/
class _DatHeader {
  late String id;
  late int fileNumber;
  late int fileOffsetsOffset;
  late int fileExtensionsOffset;
  late int fileNamesOffset;
  late int fileSizesOffset;
  late int hashMapOffset;

  _DatHeader(ByteDataWrapper bytes) {
    id = bytes.readString(4);
    fileNumber = bytes.readUint32();
    fileOffsetsOffset = bytes.readUint32();
    fileExtensionsOffset = bytes.readUint32();
    fileNamesOffset = bytes.readUint32();
    fileSizesOffset = bytes.readUint32();
    hashMapOffset = bytes.readUint32();
  }
}

Future<List<String>> extractDatFiles(String datPath, { bool shouldExtractPakFiles = false }) async {
  print("Extracting dat files from $datPath");
  messageLog.add("Extracting ${path.basename(datPath)}...");

  var bytes = await ByteDataWrapper.fromFile(datPath);
  var header = _DatHeader(bytes);
  bytes.position = header.fileOffsetsOffset;
  var fileOffsets = bytes.readUint32List(header.fileNumber);
  bytes.position = header.fileSizesOffset;
  var fileSizes = bytes.readUint32List(header.fileNumber);
  bytes.position = header.fileNamesOffset;
  var nameLength = bytes.readUint32();
  var fileNames = List<String>
    .generate(header.fileNumber, (index) => 
    bytes.readString(nameLength).split("\u0000")[0]);

  // extract dir is file path --> /nier2blender_extracted/[filename]/
  var datDir = path.dirname(datPath);
  var extractDir = path.join(datDir, datSubExtractDir, path.basename(datPath));
  await Directory(extractDir).create(recursive: true);
  List<String> filePaths = [];
  for (int i = 0; i < header.fileNumber; i++) {
    bytes.position = fileOffsets[i];
    var extractedFile = File(path.join(extractDir, fileNames[i]));
    filePaths.add(extractedFile.path);
    await extractedFile.writeAsBytes(bytes.readUint8List(fileSizes[i]));
  }

  fileNames = deduplicate(fileNames);
  dynamic jsonMetadata = {
    "version": 2,
    "files": fileNames,
    "original_order": fileNames,
    "basename": path.basename(datPath).split(".")[0],
    "ext": path.basename(datPath).split(".")[1],
  };
  await File(path.join(extractDir, "dat_info.json"))
    .writeAsString(const JsonEncoder.withIndent("\t").convert(jsonMetadata));

  if (shouldExtractPakFiles) {
    var pakFiles = fileNames.where((file) => file.endsWith(".pak"));
    await Future.wait(pakFiles.map<Future<void>>((pakFile) async {
      var pakPath = path.join(extractDir, pakFile);
      await extractPakFiles(pakPath, yaxToXml: true);
    }));
  }

  messageLog.add("Extracting ${path.basename(datPath)} done");

  return filePaths;
}

class ExtractedInnerFile {
  final String path;
  final ByteDataWrapper bytes;

  ExtractedInnerFile(this.path, this.bytes);
}

Stream<ExtractedInnerFile> extractDatFilesAsStream(String datPath) async* {
  try {
    var bytes = await ByteDataWrapper.fromFile(datPath);
    var header = _DatHeader(bytes);
    bytes.position = header.fileOffsetsOffset;
    var fileOffsets = bytes.readUint32List(header.fileNumber);
    bytes.position = header.fileSizesOffset;
    var fileSizes = bytes.readUint32List(header.fileNumber);
    bytes.position = header.fileNamesOffset;
    var nameLength = bytes.readUint32();
    var fileNames = List<String>
      .generate(header.fileNumber, (index) => 
      bytes.readString(nameLength).split("\u0000")[0]);

    for (int i = 0; i < header.fileNumber; i++) {
      bytes.position = fileOffsets[i];
      yield ExtractedInnerFile(
        path.join(datPath, fileNames[i]),
        bytes.makeSubView(fileSizes[i])
      );
    }
  } catch (e, s) {
    print("Error while extracting dat files from $datPath");
    print("$e\n$s");
    return;
  }
}

Future<void> updateDatInfoFileOriginalOrder(String datPath, String extractDir) async {
  var datInfoPath = path.join(extractDir, "dat_info.json");
  if (!await File(datInfoPath).exists())
    return;
  
  var bytes = await ByteDataWrapper.fromFile(datPath);
  var header = _DatHeader(bytes);
  bytes.position = header.fileNamesOffset;
  var nameLength = bytes.readUint32();
  var fileNames = List.generate(header.fileNumber, (index) => bytes.readString(nameLength).split("\u0000")[0]);
  fileNames = deduplicate(fileNames);
  
  var datInfo = jsonDecode(await File(datInfoPath).readAsString()) as Map;
  datInfo["original_order"] = fileNames;
  datInfo["version"] = 2;
  var datInfoJson = const JsonEncoder.withIndent("\t").convert(datInfo);
  await File(datInfoPath).writeAsString(datInfoJson);
}
