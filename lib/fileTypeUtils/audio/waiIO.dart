
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';

class WaiHeader {
  int fileType;
  int wspDirectoryCount;
  int wspNameCount;
  int structCount;

  WaiHeader(this.fileType, this.wspDirectoryCount, this.wspNameCount, this.structCount);

  WaiHeader.read(ByteDataWrapper bytes) :
    fileType = bytes.readUint32(),
    wspDirectoryCount = bytes.readUint32(),
    wspNameCount = bytes.readUint32(),
    structCount = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(fileType);
    bytes.writeUint32(wspDirectoryCount);
    bytes.writeUint32(wspNameCount);
    bytes.writeUint32(structCount);
  }

  static const int size = 16;
}

class WspDirectory {
  final String name;
  final int u0;
  final int u1;
  final int startStructIndex;
  final int endStructIndex;

  WspDirectory(this.name, this.u0, this.u1, this.startStructIndex, this.endStructIndex);

  WspDirectory.read(ByteDataWrapper bytes) :
    name = bytes.readString(16).replaceAll("\x00", ""),
    u0 = bytes.readUint32(),
    u1 = bytes.readUint32(),
    startStructIndex = bytes.readUint32(),
    endStructIndex = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeString(name);
    for (int i = 0; i < 16 - name.length; i++)
      bytes.writeUint8(0);
    bytes.writeUint32(u0);
    bytes.writeUint32(u1);
    bytes.writeUint32(startStructIndex);
    bytes.writeUint32(endStructIndex);
  }

  static const int size = 32;
}

class WspName {
  final String name;
  final int u0;
  final int u1;
  final int u2;
  final int u3;

  WspName(this.name, this.u0, this.u1, this.u2, this.u3);

  WspName.read(ByteDataWrapper bytes) :
    name = bytes.readString(16).replaceAll("\x00", ""),
    u0 = bytes.readUint32(),
    u1 = bytes.readUint32(),
    u2 = bytes.readUint32(),
    u3 = bytes.readUint32();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeString(name);
    for (int i = 0; i < 16 - name.length; i++)
      bytes.writeUint8(0);
    bytes.writeUint32(u0);
    bytes.writeUint32(u1);
    bytes.writeUint32(u2);
    bytes.writeUint32(u3);
  }

  static const int size = 32;
}

class WemStruct {
  final int wemID;
  int wemEntrySize;
  int wemOffset;
  final int wspNameIndex;
  final int wspIndex;

  WemStruct(this.wemID, this.wemEntrySize, this.wemOffset, this.wspNameIndex, this.wspIndex);

  WemStruct.read(ByteDataWrapper bytes) :
    wemID = bytes.readUint32(),
    wemEntrySize = bytes.readUint32(),
    wemOffset = bytes.readUint32(),
    wspNameIndex = bytes.readUint16(),
    wspIndex = bytes.readUint16();
  
  void write(ByteDataWrapper bytes) {
    bytes.writeUint32(wemID);
    bytes.writeUint32(wemEntrySize);
    bytes.writeUint32(wemOffset);
    bytes.writeUint16(wspNameIndex);
    bytes.writeUint16(wspIndex);
  }

  String wemToWspName(List<WspName> wspNames) {
    int index1 = wspIndex ~/ 1000;
    int index2 = wspIndex % 1000;
    return "${wspNames[wspNameIndex].name}_${index1}_${index2.toString().padLeft(3, "0")}.wsp";
  }

  static const int size = 16;
}

class WaiFile {
  late final WaiHeader header;
  late final List<WspDirectory> wspDirectories;
  late final List<WspName> wspNames;
  late final List<WemStruct> wemStructs;

  WaiFile(this.header, this.wspDirectories, this.wspNames, this.wemStructs);

  WaiFile.read(ByteDataWrapper bytes) {
    header = WaiHeader.read(bytes);
    wspDirectories = List.generate(header.wspDirectoryCount, (i) => WspDirectory.read(bytes));
    wspNames = List.generate(header.wspNameCount, (i) => WspName.read(bytes));
    wemStructs = List.generate(header.structCount, (i) => WemStruct.read(bytes));
  }

  void write(ByteDataWrapper bytes) {
    header.wspDirectoryCount = wspDirectories.length;
    header.wspNameCount = wspNames.length;
    header.structCount = wemStructs.length;
    header.write(bytes);
    for (WspDirectory wspDirectory in wspDirectories)
      wspDirectory.write(bytes);
    for (WspName wspName in wspNames)
      wspName.write(bytes);
    for (WemStruct wemStruct in wemStructs)
      wemStruct.write(bytes);
  }

  int getNameIndex(String name) {
    return wspNames.indexWhere((n) => n.name == name);
  }

  Future<void> patchWithWspDir(WspPatch wsp, String exportDir) async {
    // get info about wsp
    var folderPaths = wsp.wspName.split("_");
    var wspName = folderPaths[0];
    var wspNameIndex = getNameIndex(wspName);
    if (wspNameIndex == -1)
      throw Exception("Could not find WSP name $wspName in WAI file");
    var wspIndex1 = int.parse(folderPaths[1]);
    var wspIndex2 = int.parse(folderPaths[2]);
    var wspIndex = wspIndex1 * 1000 + wspIndex2;
    var wspWemStructs = wemStructs
      .where((w) => w.wspNameIndex == wspNameIndex && w.wspIndex == wspIndex)
      .toList();

    // map wem ID --> wem path    
    Map<int, String> idToWemFiles;
    try {
      idToWemFiles = {
        for (var f in wsp.wemFiles)
          f.wemID: f.wemPath
      };
    } catch (e) {
      print(e);
      throw Exception("Could not parse WEM file names in ${wsp.wspName}");
    }

    // check if any wem IDs are missing
    var missingIds = wspWemStructs
      .where((w) => !idToWemFiles.containsKey(w.wemID))
      .map((w) => w.wemID)
      .toList();
    if (missingIds.isNotEmpty)
      throw Exception("Missing WEM files for IDs $missingIds in ${wsp.wspName}");
    
    // update offsets and sizes
    var curOffset = 0;
    for (var wemStruct in wspWemStructs) {
      var wemPath = idToWemFiles[wemStruct.wemID]!;
      var wemSize = await File(wemPath).length();
      wemStruct.wemEntrySize = wemSize;
      wemStruct.wemOffset = curOffset;
      curOffset += wemSize;
    }

    // fix export directory
    var wemStructIndex = wemStructs.indexOf(wspWemStructs[0]);
    var waiDir = wspDirectories.firstWhere((d) => d.startStructIndex >= wemStructIndex && wemStructIndex < d.endStructIndex);
    if (waiDir.name.isNotEmpty)
      exportDir = join(exportDir, waiDir.name);

    // make new WSP file
    var wspSavePath = join(exportDir, "${wspName}_${wspIndex1}_${wspIndex2.toString().padLeft(3, "0")}.wsp");
    makeWsp(wspWemStructs, idToWemFiles, wspSavePath);

    messageLog.add("Patched ${wspWemStructs.length} WEM files from $wspName");
  }

  int get size => WaiHeader.size + wspDirectories.length * WspDirectory.size + wspNames.length * WspName.size + wemStructs.length * WemStruct.size;
}

Future<void> makeWsp(List<WemStruct> wemFiles, Map<int, String> idToWemFiles, String savePath) async {
  backupFile(savePath);
  var wsp = await File(savePath).open();
  try {
    var sortedWemFiles = wemFiles.toList();
    sortedWemFiles.sort((a, b) => a.wemOffset.compareTo(b.wemOffset));
    for (WemStruct wem in sortedWemFiles) {
      if (!idToWemFiles.containsKey(wem.wemID))
        throw Exception("Missing wem file for id ${wem.wemID}");
      var wemBytes = await File(idToWemFiles[wem.wemID]!).readAsBytes();
      await wsp.setPosition(wem.wemOffset);
      await wsp.writeFrom(wemBytes);
    }
  } finally {
    await wsp.close();
  }
}

class WspPatchWem {
  final String wemPath;
  final int wemID;

  const WspPatchWem(this.wemPath, this.wemID);

  @override
  int get hashCode => Object.hash(wemPath, wemID);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WspPatchWem && other.wemPath == wemPath && other.wemID == wemID;
  }
}
class WspPatch {
  final String wspName;
  final List<WspPatchWem> wemFiles;

  const WspPatch(this.wspName, this.wemFiles);

  @override
  int get hashCode => Object.hash(wspName, wemFiles);
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WspPatch && other.wspName == wspName && other.wemFiles == wemFiles;
  }
}
