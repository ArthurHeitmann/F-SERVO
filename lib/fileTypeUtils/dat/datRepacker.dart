
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';
import 'datHashGenerator.dart';

Future<void> repackDat(String datDir, String exportPath) async {
  messageLog.add("Repacking ${path.basename(exportPath)}...");
  
  var fileList = await getDatFileList(datDir);
  var fileNames = fileList.map((e) => path.basename(e)).toList();
  var allFilesExists = (await Future.wait(fileList.map((e) => File(e).exists())));
  var missingFiles = <String>[];
  for (var i = 0; i < allFilesExists.length; i++) {
    if (!allFilesExists[i]) {
      missingFiles.add(fileNames[i]);
    }
  }
  if (missingFiles.isNotEmpty) {
    for (var f in missingFiles)
      messageLog.add("Missing file: ${basename(f)}");
    showToast("DAT is missing ${pluralStr(missingFiles.length, "file")}. Check log for details");
    return;
  }
  var fileSizes = (await Future.wait(fileList.map((e) => File(e).length()))).toList();
  var fileNumber = fileList.length;
  var hashData = HashInfo(fileNames);

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
  var namesSize = nameLength * fileNumber;
  var namesPadding = 4 - (namesSize % 4);

  var hashMapSize = hashData.getTableSize();

  // Header
  var fileID = "DAT";
  var fileOffsetsOffset = 32;
  var fileExtensionsOffset = fileOffsetsOffset + (fileNumber * 4);
  var fileNamesOffset = fileExtensionsOffset + fileExtensionsSize;
  var fileSizesOffset = fileNamesOffset + 4 + (fileNumber * nameLength) + namesPadding;
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
  await Directory(path.dirname(exportPath)).create(recursive: true);
  var datSize = fileOffsets.last + fileSizes.last + 1;
  if (datSize % 16 != 0)
    datSize = (datSize / 16).ceil() * 16;
  var datBytes = ByteDataWrapper.allocate(datSize);
  datBytes.writeString0P(fileID);
  datBytes.writeUint32(fileNumber);
  datBytes.writeUint32(fileOffsetsOffset);
  datBytes.writeUint32(fileExtensionsOffset);
  datBytes.writeUint32(fileNamesOffset);
  datBytes.writeUint32(fileSizesOffset);
  datBytes.writeUint32(hashMapOffset);
  datBytes.writeBytes(Uint8List(4));

  // fileOffsets
  datBytes.position = fileOffsetsOffset;
  for (var value in fileOffsets) {
    datBytes.writeUint32(value);
  }

  // fileExtensions
  datBytes.position = fileExtensionsOffset;
  for (var value in fileExtensions) {
    datBytes.writeString0P(value);
  }

  // nameLength
  datBytes.position = fileNamesOffset;
  datBytes.writeUint32(nameLength);

  // fileNames
  datBytes.position = fileNamesOffset + 4;
  for (var value in fileNames) {
    datBytes.writeString0P(value);
    if (value.length < nameLength)
      datBytes.writeBytes(Uint8List(nameLength - value.length - 1));
  }

  // fileSizes
  datBytes.position = fileSizesOffset;
  for (var value in fileSizes) {
    datBytes.writeUint32(value);
  }

  // hashMap
  datBytes.position = hashMapOffset;
  datBytes.writeUint32(hashData.preHashShift);
  datBytes.writeUint32(16);
  datBytes.writeUint32(16 + hashData.bucketsSize);
  datBytes.writeUint32(16 + hashData.bucketsSize + hashData.hashesSize);
  for (var value in hashData.bucketOffsets)
    datBytes.writeUint16(value);
  for (var value in hashData.hashes)
    datBytes.writeUint32(value);
  for (var value in hashData.indices)
    datBytes.writeUint16(value);


  // Files
  for (var i = 0; i < fileList.length; i++) {
    datBytes.position = fileOffsets[i];
    var fileData = await File(fileList[i]).readAsBytes();
    datBytes.writeBytes(fileData);
  }

  await datFile.writeAsBytes(datBytes.buffer.asUint8List());

  messageLog.add("Repacking ${path.basename(exportPath)} done");
}
