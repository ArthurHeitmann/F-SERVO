
import '../utils/ByteDataWrapper.dart';
import 'bnkIO.dart';
import 'streamIds.dart';

Future<Iterable<int>> removePrefetchWems(String bnkPath) async {
  var bnk = BnkFile.read(await ByteDataWrapper.fromFile(bnkPath));
  var didx = bnk.chunks.whereType<BnkDidxChunk>().firstOrNull;
  var data = bnk.chunks.whereType<BnkDataChunk>().firstOrNull;
  var hirc = bnk.chunks.whereType<BnkHircChunk>().firstOrNull;
  if (didx == null) {
    return {};
  }
  if (data == null) {
    return {};
  }
  if (hirc == null) {
    return {};
  }

  var bnkWemIds = didx.files
    .map((file) => file.id)
    .toSet();

  Set<int> prefetchedWemIds = {};

  for (var track in hirc.chunks.whereType<BnkMusicTrack>()) {
    for (var source in track.sources) {
      if (source.streamType != 2)
        continue;
      var playlist = track.playlists.where((playlist) => playlist.sourceID == source.sourceID).firstOrNull;
      if (playlist == null) {
        print("WARNING: Track ${track.uid} has no playlist for source ${source.sourceID}, skipping ($bnkPath)");
        continue;
      }
      if (!bnkWemIds.contains(source.sourceID)) {
        print("WARNING: Track ${track.uid} has source ${source.sourceID}, but it is not in the bnk DIDX ($bnkPath)");
        continue;
      }
      if (!streamIds.contains(source.fileID)) {
        print("WARNING: Track ${track.uid} has source ${source.sourceID}, but it is not in the stream cpk ($bnkPath)");
        continue;
      }
      prefetchedWemIds.add(source.sourceID);
      source.streamType = 1;
      source.sourceID = source.fileID;
      playlist.sourceID = source.fileID;
    }
    track.size = track.calculateSize() + 4;
  }

  if (prefetchedWemIds.isEmpty) {
    // print("No prefetched WEMs found in $bnkPath");
    return {};
  }

  var wemIndicesToRemove = didx.files
    .indexed
    .where((file) => prefetchedWemIds.contains(file.$2.id))
    .map((file) => file.$1)
    .toList();
  for (var index in wemIndicesToRemove.reversed) {
    didx.files.removeAt(index);
    data.wemFiles.removeAt(index);    
  }
  int offset = 0;
  for (var file in didx.files) {
    file.offset = offset;
    offset += file.size;
    offset = (offset + 15) & ~15;
  }
  didx.chunkSize = didx.calculateSize() - 8;
  data.chunkSize = data.calculateSize() - 8;

  var bytes = ByteDataWrapper.allocate(bnk.calculateSize());
  bnk.write(bytes);
  await bytes.save(bnkPath);

  return prefetchedWemIds;
}
