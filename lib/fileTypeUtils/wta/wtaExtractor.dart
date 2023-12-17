
import 'dart:io';

import 'package:path/path.dart';

import 'wtaReader.dart';

Future<List<String>> extractWta(String wtaPath, String? wtpPath, bool isWtb) async {
  List<String> texturePaths = [];
  var extractDir = join(dirname(wtaPath), "nier2blender_extracted", basename(wtaPath));
  await Directory(extractDir).create(recursive: true);
  var wta = await WtaFile.readFromFile(wtaPath);
  var wtpFile = await File(isWtb ? wtaPath : wtpPath!).open();
  try {
    for (int i = 0; i < wta.textureOffsets.length; i++) {
      var texturePath = join(extractDir, "${i}_${wta.textureIdx[i].toRadixString(16).padLeft(8, "0")}.dds");
      texturePaths.add(texturePath);
      await wtpFile.setPosition(wta.textureOffsets[i]);
      var textureBytes = await wtpFile.read(wta.textureSizes[i]);
      await File(texturePath).writeAsBytes(textureBytes);
    }
  } finally {
    await wtpFile.close();
  }
  return texturePaths;
}
