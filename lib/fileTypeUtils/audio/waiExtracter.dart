
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import 'waiIO.dart';

abstract class WaiChild {
  final String name;

  const WaiChild(this.name);
}
class WaiChildList extends WaiChild {
  final List<WaiChild> children;

  const WaiChildList(String name, this.children) : super(name);
}
class WaiChildDir extends WaiChildList {
  const WaiChildDir(String name, List<WaiChild> children) : super(name, children);
}
class WaiChildWsp extends WaiChildList {
  const WaiChildWsp(String name, List<WaiChild> children) : super(name, children);
}
class WaiChildWem extends WaiChild {
  const WaiChildWem(String name) : super(name);
}
Future<List<WaiChild>> extractWaiWsps(WaiFile wai, String waiPath, String extractPath, [bool noExtract = false]) async {
  List<WaiChild> structure = [];
  String waiDir = dirname(waiPath);
  for (var dir in wai.wspDirectories) {
    String wspsDir = dir.name.isNotEmpty ? join(extractPath, dir.name) : extractPath;
    await Directory(wspsDir).create(recursive: true);
    List<WaiChild> wspFilesInDir = structure;
    if (dir.name.isNotEmpty) {
      wspFilesInDir = [];
      structure.add(WaiChildDir(dir.name, wspFilesInDir));
    }
    List<WemStruct> dirWemStructs = List.generate(
      dir.endStructIndex - dir.startStructIndex,
      (i) => wai.wemStructs[dir.startStructIndex + i]
    );
    Map<String, List<WemStruct>> wemStructsByWspName = {};
    for (var wemStruct in dirWemStructs) {
      var wspName = wemStruct.wemToWspName(wai.wspNames);
      if (!wemStructsByWspName.containsKey(wspName))
        wemStructsByWspName[wspName] = [];
      wemStructsByWspName[wspName]!.add(wemStruct);
    }
    for (String wspName in wemStructsByWspName.keys) {
      List<WemStruct> wemStructs = wemStructsByWspName[wspName]!;
      wemStructs.sort((a, b) => a.wemOffset.compareTo(b.wemOffset));
      String wspPath = join(waiDir, "stream");
      if (dir.name.isNotEmpty)
        wspPath = join(wspPath, dir.name);
      wspPath = join(wspPath, wspName);
      String wspExtractDir = join(wspsDir, wspName);

      List<WaiChild> wemFilesInWsp = [];
      wspFilesInDir.add(WaiChildWsp(wspName, wemFilesInWsp));
      if (noExtract) {
        wemFilesInWsp.addAll([
          for (var wem in wemStructs)
            WaiChildWem(join(wspExtractDir, "${wem.wemID}.wem"))
        ]);
        continue;
      }
      messageLog.add("Extracting $wspName");
      await Directory(wspExtractDir).create(recursive: true);
      var wspFile = await File(wspPath).open();
      try {
        for (var wemStruct in wemStructs) {
          var wemPath = join(wspExtractDir, "${wemStruct.wemID}.wem");
          var wemFile = File(wemPath);
          await wspFile.setPosition(wemStruct.wemOffset);
          await wemFile.writeAsBytes(await wspFile.read(wemStruct.wemEntrySize));
          wemFilesInWsp.add(WaiChildWem(wemPath));
        }
      } finally {
        await wspFile.close();
      }
    }
  }

  return structure;
}
