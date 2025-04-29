

import 'package:path/path.dart';

import '../utils/ByteDataWrapper.dart';
import 'bnkIO.dart';
import 'wemIdsToNames.dart';
import '../../fileSystem/FileSystem.dart';

Future<List<({int id, String path, bool isPrefetched})>> extractBnkWems(BnkFile bnk, String extractPath, [bool noExtract = false]) async {
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

  Set<int> prefetchedIds = {};
  var hirc = bnk.chunks.whereType<BnkHircChunk>().first;
  for (var chunk in hirc.chunks) {
    List<({int id, int streamType})> sources = [];
    if (chunk is BnkSound) {
      sources.add((id: chunk.bankData.mediaInformation.sourceID, streamType: chunk.bankData.streamType));
    } else if (chunk is BnkMusicTrack) {
      for (var src in chunk.sources)
        sources.add((id: src.sourceID, streamType: src.streamType));
    }
    for (var src in sources) {
      if (src.streamType == 2)
        prefetchedIds.add(src.id);
    }
  }

  await FS.i.createDirectory(extractPath);

  List<({int id, String path, bool isPrefetched})> wems = [];
  for (int i = 0; i < didx.length; i++) {
    var entry = didx[i];
    var wemId = entry.id;
    var lookupName = wemIdsToNames[wemId] ?? "";
    var wemFileName = "${i}_${lookupName}_$wemId.wem";
    var bytes = data[i];

    var savePath = join(extractPath, wemFileName);
    wems.add((id: wemId, path: savePath, isPrefetched: prefetchedIds.contains(wemId)));
    if (noExtract)
      continue;
    var byteData = ByteDataWrapper.allocate(bytes.length);
    byteData.buffer.asUint8List().setAll(0, bytes);
    await byteData.save(savePath);
  }

  return wems;
}

Future<List<String>> extractBnkWemsFromPath(String bnkPath) async {
  var bnk = BnkFile.read(await ByteDataWrapper.fromFile(bnkPath));
  var extractPath = join(dirname(bnkPath), "${basename(bnkPath)}_extracted");
  var wems = await extractBnkWems(bnk, extractPath);
  return wems.map((e) => e.path).toList();
}
