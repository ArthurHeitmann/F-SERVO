
import 'dart:io';

import 'package:path/path.dart';

import '../../utils/utils.dart';
import 'wtaReader.dart';

Future<List<String>> extractWta(String wtaPath, String? wtpPath, bool isWtb) async {
  List<String> texturePaths = [];
  var extractDir = join(dirname(wtaPath), datSubExtractDir, basename(wtaPath));
  await Directory(extractDir).create(recursive: true);
  var wta = await WtaFile.readFromFile(wtaPath);
  var wtpFile = await File(isWtb ? wtaPath : wtpPath!).open();
  try {
    for (int i = 0; i < wta.textureOffsets.length; i++) {
      var texturePath = getWtaTexturePath(wta, i, extractDir);
      var texturePathOld = getWtaTexturePathOld(wta, i, extractDir);
      texturePaths.add(texturePath);
      if (await File(texturePathOld).exists())
        await File(texturePathOld).rename(texturePath);
      if (await File(texturePath).exists())
        continue;
      await wtpFile.setPosition(wta.textureOffsets[i]);
      var textureBytes = await wtpFile.read(wta.textureSizes[i]);
      await File(texturePath).writeAsBytes(textureBytes);
    }
  } finally {
    await wtpFile.close();
  }
  return texturePaths;
}

String getWtaTexturePathOld(WtaFile wta, int i, String extractDir) {
  String idStr = "";
  if (wta.textureIdx != null)
    idStr = "_${wta.textureIdx![i].toRadixString(16)}";
  return join(extractDir, "$i$idStr.dds");
}

String getWtaTexturePath(WtaFile wta, int i, String extractDir) {
  String idStr = "";
  if (wta.textureIdx != null)
    idStr = "_${wta.textureIdx![i].toString()}";
  return join(extractDir, "$i$idStr.dds");
}
