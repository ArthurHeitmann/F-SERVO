
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

// import '../../stateManagement/events/statusInfo.dart';
// import '../pak/pakExtractor.dart';
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

Future<List<String>> extractDatFiles(String datPath, { String? extractDir, bool shouldExtractPakFiles = false }) async {
  // print("Extracting dat files from $datPath");
  // messageLog.add("Extracting ${path.basename(datPath)}...");

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
  if (extractDir == null) {
    var datDir = path.dirname(datPath);
    extractDir = path.join(datDir, "nier2blender_extracted", path.basename(datPath));
  }
  await Directory(extractDir).create(recursive: true);
  for (int i = 0; i < header.fileNumber; i++) {
    bytes.position = fileOffsets[i];
    var extractedFile = File(path.join(extractDir, fileNames[i]));
    await extractedFile.writeAsBytes(bytes.readUint8List(fileSizes[i]));
  }

  fileNames.sort(((a, b) {
    var aBaseExt = a.split(".").map((e) => e.toLowerCase()).toList();
    var bBaseExt = b.split(".").map((e) => e.toLowerCase()).toList();
    if (aBaseExt[0] == bBaseExt[0])
      return aBaseExt[1].compareTo(bBaseExt[1]);
    else
      return aBaseExt[0].compareTo(bBaseExt[0]);
  }));
  dynamic jsonMetadata = {
    "version": 1,
    "files": fileNames,
    "basename": path.basename(datPath).split(".")[0],
    "ext": path.basename(datPath).split(".")[1],
  };
  await File(path.join(extractDir, "dat_info.json"))
    .writeAsString(const JsonEncoder.withIndent("\t").convert(jsonMetadata));

  // if (shouldExtractPakFiles) {
  //   var pakFiles = fileNames.where((file) => file.endsWith(".pak"));
  //   await Future.wait(pakFiles.map<Future<void>>((pakFile) async {
  //     var pakPath = path.join(extractDir, pakFile);
  //     await extractPakFiles(pakPath, yaxToXml: true);
  //   }));
  // }

  // messageLog.add("Extracting ${path.basename(datPath)} done");

  return fileNames;
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
  } catch (e) {
    print("Error while extracting dat files from $datPath");
    return;
  }
}
