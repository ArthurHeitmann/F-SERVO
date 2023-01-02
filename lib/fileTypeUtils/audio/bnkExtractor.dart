
import 'dart:io';

import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../utils/ByteDataWrapper.dart';
import 'bnkIO.dart';
import 'wemIdsToNames.dart';

Future<List<Tuple2<int, String>>> extractBnkWems(BnkFile bnk, String extractPath, [bool noExtract = false]) async {
  if (!bnk.chunks.any((chunk) => chunk.chunkId == "DIDX")) {
    print("No DIDX chunk found in BNK");
    return [];
  }
  if (!bnk.chunks.any((chunk) => chunk.chunkId == "DATA")) {
    print("No DATA chunk found in BNK");
    return [];
  }

  var didx = bnk.chunks.whereType<BnkDidxChunk>().first.files.toList();
  var data = bnk.chunks.whereType<BnkDataChunk>().first.wemFiles.toList();
  assert(didx.length == data.length);

  await Directory(extractPath).create(recursive: true);

  List<Tuple2<int, String>> wems = [];
  for (int i = 0; i < didx.length; i++) {
    var entry = didx[i];
    var wemId = entry.id;
    var lookupName = wemIdsToNames[wemId] ?? "";
    var wemFileName = "${i}_${lookupName}_$wemId.wem";
    var bytes = data[i];

    var savePath = join(extractPath, wemFileName);
    wems.add(Tuple2(wemId, savePath));
    if (noExtract)
      continue;
    var byteData = ByteDataWrapper.allocate(bytes.length);
    byteData.buffer.asUint8List().setAll(0, bytes);
    await File(savePath).writeAsBytes(bytes);
  }

  return wems;
}
