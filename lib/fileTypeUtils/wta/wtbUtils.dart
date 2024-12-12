
import 'dart:io';

import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';
import 'wtaReader.dart';

class WtbUtils {
  static Future<int> getSingleId(String wtbPath) async {
    var bytes = await ByteDataWrapper.fromFile(wtbPath);
    var wtb = WtaFile.read(bytes);
    if (wtb.header.numTex != 1)
      throw Exception("Expected 1 texture, got ${wtb.header.numTex}");
    return wtb.textureIdx![0];
  }

  static Future<void> extractSingle(String wtbPath, String ddsPath) async {
    var bytes = await ByteDataWrapper.fromFile(wtbPath);
    var wtb = WtaFile.read(bytes);
    if (wtb.header.numTex != 1)
      throw Exception("Expected 1 texture, got ${wtb.header.numTex}");
    bytes.position = wtb.textureOffsets[0];
    var texBytes = bytes.asUint8List(wtb.textureSizes[0]);
    await File(ddsPath).writeAsBytes(texBytes);
  }

  static Future<void> replaceSingle(String wtbPath, String ddsPath) async {
    var bytes = await ByteDataWrapper.fromFile(wtbPath);
    var wtb = WtaFile.read(bytes);
    if (wtb.header.numTex != 1)
      throw Exception("Expected 1 texture, got ${wtb.header.numTex}");
    
    var texBytes = await File(ddsPath).readAsBytes();
    var bytesNew = ByteDataWrapper.allocate(wtb.textureOffsets[0] + texBytes.length);
    wtb.textureSizes[0] = texBytes.length;
    wtb.write(bytesNew);
    bytesNew.buffer.asUint8List().setAll(wtb.textureOffsets[0], texBytes);
    await backupFile(wtbPath);
    await bytesNew.save(wtbPath);
  }
}
