
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';
import 'wwiseTransitionList.dart';
import 'wwiseTriggers.dart';

class _PlaylistItemHierarchy {
  final BnkPlaylistItem item;
  final List<_PlaylistItemHierarchy> children;
  
  _PlaylistItemHierarchy(this.item, this.children);
  
  factory _PlaylistItemHierarchy.fromList(List<BnkPlaylistItem> items) {
    var item = items.removeAt(0);
    List<_PlaylistItemHierarchy> children = [];
    for (int i = 0; i < item.numChildren; i++) {
      children.add(_PlaylistItemHierarchy.fromList(items));
    }
    return _PlaylistItemHierarchy(item, children);
  }

  WwiseElement toElement(WwiseProjectGenerator project, String wuId) {
    var segment = project.lookupElement(idFnv: item.segmentId);
    return WwiseElement(
      wuId: wuId,
      project: project,
      tagName: "MusicPlaylistItem",
      name: "",
      shortId: item.playlistItemId,
      properties: [
        if (item.segmentId > 0)
          WwiseProperty("PlaylistItemType", "int16", value: "1"),
        if (item.loop != 1)
          WwiseProperty("LoopCount", "int16", value: item.loop.toString()),
        if (item.weight != 50000)
          WwiseProperty("Weight", "int16", values: [(item.weight / 1000).toString()]),
        if (item.eRSType > 0)
          WwiseProperty("PlayMode", "int16", value: item.eRSType.toString()),
        if (item.bIsShuffle == 1)
          WwiseProperty("NormalOrShuffle", "int16", value: "0"),
        if (item.wAvoidRepeatCount != 1)
          WwiseProperty("RandomAvoidRepeatingCount", "int32", value: item.wAvoidRepeatCount.toString()),
      ],
      additionalChildren: [
        if (item.segmentId > 0 && segment is WwiseElement)
          makeXmlElement(name: "SegmentRef", attributes: { "Name": segment.name, "ID": segment.id }),
      ],
      children: children.map((child) => child.toElement(project, wuId)).toList(),
    );
  }
}

class WwiseMusicPlaylist extends WwiseHierarchyElement<BnkMusicPlaylist> {
  WwiseMusicPlaylist({required super.wuId, required super.project, required super.chunk}) : super(
    tagName: "MusicPlaylistContainer",
    name: makeElementName(project, id: chunk.uid, category: "Music Playlist Container", parentId: chunk.getBaseParams().directParentID, childIds: chunk.musicTransParams.musicParams.childrenList.ulChildIDs, addId: true),
    shortId: chunk.uid
  );
  
  @override
  void oneTimeInit() {
    super.oneTimeInit();
    additionalChildren.add(makeWwiseTransitionList(project, wuId, chunk.musicTransParams.rules));
    var stingerList = makeStingerList(project, wuId, chunk.musicTransParams.musicParams.stingers);
    if (stingerList != null)
      additionalChildren.add(stingerList);
    var hierarchy = _PlaylistItemHierarchy.fromList(chunk.playlistItems.toList());
    additionalChildren.add(makeXmlElement(
      name: "Playlist",
      children: [hierarchy.toElement(project, wuId).toXml()],
    ));
  }
}
