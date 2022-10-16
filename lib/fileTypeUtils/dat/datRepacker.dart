
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import '../utils/ByteDataWrapper.dart';
import 'datHashGenerator.dart';

Future<List<String>> getDatFileList(String datDir) async {
  var datInfoPath = path.join(datDir, "dat_info.json");
  if (await File(datInfoPath).exists())
    return _getDatFileListFromJson(datInfoPath);
  var metadataPath = path.join(datDir, "file_order.metadata");
  if (await File(metadataPath).exists())
    return _getDatFileListFromMetadata(metadataPath);
  
  throw Exception("No dat_info.json or file_order.metadata found in $datDir");
}

Future<List<String>> _getDatFileListFromJson(String datInfoPath) async {
  var datInfoJson = jsonDecode(await File(datInfoPath).readAsString());
  List<String> files = [];
  var dir = path.dirname(datInfoPath);
  for (var file in datInfoJson["files"]) {
    files.add(path.join(dir, file));
  }
  files = files.toSet().toList();
  files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return files;
}

Future<List<String>> _getDatFileListFromMetadata(String metadataPath) async {
  var metadataBytes = ByteDataWrapper((await File(metadataPath).readAsBytes()).buffer);
  var numFiles = metadataBytes.readUint32();
  var nameLength = metadataBytes.readUint32();
  List<String> files = [];
  for (var i = 0; i < numFiles; i++)
    files.add(metadataBytes.readString(nameLength).replaceAll("\x00", ""));
  files = files.toSet().toList();
  files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return files;
}

Future<void> repackDat(String datDir, String exportPath) async {
  var fileList = await getDatFileList(datDir);
  var fileNames = fileList.map((e) => path.basename(e)).toList();
  var fileSizes = (await Future.wait(fileList.map((e) => File(e).length()))).toList();
  var fileNumber = fileList.length;
  var hashData = generateHashData(fileList);

  var fileExtensionsSize = 0;
  List<String> fileExtensions = [];
  for (var f in fileNames) {
    var fileExt = path.extension(f).substring(1);
    fileExt += '\x00' * (3 - fileExt.length);
    fileExtensionsSize += fileExt.length + 1;
    fileExtensions.add(fileExt);
  }

  var nameLength = 0;
  for (var f in fileList) {
    var fileName = path.basename(f);
    if (fileName.length + 1 > nameLength)
      nameLength = fileName.length + 1;
  }

  var hashMapSize = hashData.getStructSize();

  // Header
  var fileID = "DAT";
  var fileOffsetsOffset = 32;
  var fileExtensionsOffset = fileOffsetsOffset + (fileNumber * 4);
  var fileNamesOffset = fileExtensionsOffset + fileExtensionsSize;
  var fileSizesOffset = fileNamesOffset + (fileNumber * nameLength) + 4;
  var hashMapOffset = fileSizesOffset + (fileNumber * 4);

  // fileOffsets
  List<int> fileOffsets = [];
  var currentOffset = hashMapOffset + hashMapSize;
  for (int i = 0; i < fileList.length; i++) {
    currentOffset = (currentOffset / 16).ceil() * 16;
    fileOffsets.add(currentOffset);
    currentOffset += fileSizes[i];
  }

  // WRITE
  // Header
  var datFile = File(exportPath);
  var datSize = fileOffsets.last + fileSizes.last + 1;
  var datBytes = ByteDataWrapper(ByteData(datSize).buffer);
  datBytes.writeString0P(fileID);
  datBytes.writeUint32(fileNumber);
  datBytes.writeUint32(fileOffsetsOffset);
  datBytes.writeUint32(fileExtensionsOffset);
  datBytes.writeUint32(fileNamesOffset);
  datBytes.writeUint32(fileSizesOffset);
  datBytes.writeUint32(hashMapOffset);
  datBytes.writeBytes(Uint8List(4));

  // fileOffsets
  for (var value in fileOffsets) {
    datBytes.writeUint32(value);
  }

  // fileExtensions
  for (var value in fileExtensions) {
    datBytes.writeString0P(value);
  }

  // nameLength
  datBytes.writeUint32(nameLength);

  // fileNames
  for (var value in fileNames) {
    datBytes.writeString0P(value);
    if (value.length < nameLength)
      datBytes.writeBytes(Uint8List(nameLength - value.length - 1));
  }

  // fileSizes
  for (var value in fileSizes) {
    datBytes.writeUint32(value);
  }

  // hashMap
  hashData.write(datBytes);

  // Files
  for (var i = 0; i < fileList.length; i++) {
    datBytes.position = fileOffsets[i];
    var fileData = await File(fileList[i]).readAsBytes();
    datBytes.writeBytes(fileData);
  }

  await datFile.writeAsBytes(datBytes.buffer.asUint8List());

  print('DAT/DTT Export Complete. :>');
}
