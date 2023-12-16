
import '../utils/ByteDataWrapper.dart';
import 'bnkIO.dart';

Future<Map<int, Set<int>>> getWemIdsToBnkPlaylists(String bnkPath) async {
  var bnk = BnkFile.read(await ByteDataWrapper.fromFile(bnkPath));
  var hirc = bnk.chunks.whereType<BnkHircChunk>().first;
  var hircData = hirc.chunks.whereType<BnkHircChunkBase>().toList();
  Map<int, BnkHircChunkBase> hircMap = {
    for (var hirc in hirc.chunks.whereType<BnkHircChunkBase>())
      hirc.uid: hirc
  };
  var playlists = hircData.whereType<BnkMusicPlaylist>();
  Map<int, Set<int>> playlistIdsToSources = {
    for (var playlist in playlists)
      playlist.uid: playlist.playlistItems
          .map((e) => e.segmentId)
          .where((e) => e != 0)
          .map((e) => (hircMap[e] as BnkMusicSegment).musicParams.childrenList.ulChildIDs)
          .expand((e) => e)
          .map((e) => (hircMap[e] as BnkMusicTrack).playlists)
          .expand((e) => e)
          .map((e) => e.sourceID)
          .toSet()
  };
  Map<int, Set<int>> wemIdsToBnkPlaylists = {};
  for (var playlistKV in playlistIdsToSources.entries) {
    for (var sourceId in playlistKV.value) {
      if (!wemIdsToBnkPlaylists.containsKey(sourceId))
        wemIdsToBnkPlaylists[sourceId] = {};
      wemIdsToBnkPlaylists[sourceId]!.add(playlistKV.key);
    }
  }
  return wemIdsToBnkPlaylists;
}
