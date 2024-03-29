
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/events/miscEvents.dart';
import '../../stateManagement/events/statusInfo.dart';
import 'waiIO.dart';

abstract class WaiChild {
  final String name;

  const WaiChild(this.name);
}
class WaiChildList extends WaiChild {
  final List<WaiChild> children;

  const WaiChildList(super.name, this.children);
}
class WaiChildDir extends WaiChildList {
  final String path;

  const WaiChildDir(String name, this.path, List<WaiChild> children) : super(name, children);
}
class WaiChildWsp extends WaiChildList {
  final String path;

  const WaiChildWsp(String name, this.path, List<WaiChild> children) : super(name, children);
}
class WaiChildWem extends WaiChild {
  final String path;
  final int wemId;

  const WaiChildWem(super.name, this.path, this.wemId);
}
Future<List<WaiChild>> extractWaiWsps(WaiFile wai, String waiPath, String extractPath, [bool noExtract = false]) async {
  List<WaiChild> structure = [];
  String waiDir = dirname(waiPath);
  bool hasExtractedFiles = false;
  await Future.wait(wai.wspDirectories.map((dir) async {
    String wspsDir = dir.name.isNotEmpty ? join(extractPath, dir.name) : extractPath;
    await Directory(wspsDir).create(recursive: true);
    List<WaiChild> wspFilesInDir = structure;
    if (dir.name.isNotEmpty) {
      wspFilesInDir = [];
      structure.add(WaiChildDir(dir.name, join(extractPath, dir.name), wspFilesInDir));
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
    await Future.wait(wemStructsByWspName.keys.map((wspName) async {
      List<WemStruct> wemStructs = wemStructsByWspName[wspName]!;
      wemStructs.sort((a, b) => a.wemOffset.compareTo(b.wemOffset));
      String wspPath = join(waiDir, "stream");
      if (dir.name.isNotEmpty)
        wspPath = join(wspPath, dir.name);
      wspPath = join(wspPath, wspName);
      String wspExtractDir = join(wspsDir, wspName);

      List<WaiChild> wemFilesInWsp = [];
      wspFilesInDir.add(WaiChildWsp(wspName, wspExtractDir, wemFilesInWsp));
      if (noExtract) {
        wemFilesInWsp.addAll([
          for (int i = 0; i < wemStructs.length; i++)
            WaiChildWem(wemStructs[i].toFileName(i), join(wspExtractDir, wemStructs[i].toFileName(i)), wemStructs[i].wemID)
        ]);
        return;
      }
      await Directory(wspExtractDir).create(recursive: true);
      var wspFile = await File(wspPath).open();
      try {
        for (int i = 0; i < wemStructs.length; i++) {
          var wemStruct = wemStructs[i];
          var wemPath = join(wspExtractDir, wemStruct.toFileName(i));
          var wemFile = File(wemPath);
          await wspFile.setPosition(wemStruct.wemOffset);
          await wemFile.writeAsBytes(await wspFile.read(wemStruct.wemEntrySize));
          wemFilesInWsp.add(WaiChildWem(wemStruct.toFileName(i), wemPath, wemStruct.wemID));
        }
        messageLog.add("Extracted $wspName");
        hasExtractedFiles = true;
      } finally {
        await wspFile.close();
      }
    }));

    wspFilesInDir.sort((a, b) => a.name.compareTo(b.name));
  }));

  structure.sort((a, b) => a.name.compareTo(b.name));

  if (hasExtractedFiles)
    onWaiFilesExtracted.add(null);

  return structure;
}
