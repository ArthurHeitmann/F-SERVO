
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';
import 'wwiseTriggers.dart';

class WwiseMusicSegment extends WwiseHierarchyElement<BnkMusicSegment> {
  WwiseMusicSegment({required super.wuId, required super.project, required super.chunk}) : super(
    tagName: "MusicSegment",
    name: makeElementName(project, id: chunk.uid, category: "Music Segment", parentId: chunk.getBaseParams().directParentID, childIds: chunk.musicParams.childrenList.ulChildIDs),
    shortId: chunk.uid,
    properties: [
      if (chunk.wwiseMarkers.length >= 2)
        WwiseProperty("EndPosition", "Real64", value: chunk.wwiseMarkers.last.fPosition.toString()),
    ]
  );
  
  @override
  void oneTimeInit() {
    super.oneTimeInit();

    var stingerList = makeStingerList(project, wuId, chunk.musicParams.stingers);
    if (stingerList != null)
      additionalChildren.add(stingerList);

    additionalChildren.add(makeXmlElement(name: "CueList", children: chunk.wwiseMarkers.map((marker) {
      return WwiseElement(
        wuId: wuId,
        project: project,
        tagName: "MusicCue",
        name: marker.pMarkerName ?? (
          marker == chunk.wwiseMarkers.first ? "Entry Cue" :
          marker == chunk.wwiseMarkers.last ? "Exit Cue" :
          ""
        ),
        shortIdHint: marker.id,
        properties: [
          if (marker != chunk.wwiseMarkers.first)
            WwiseProperty("CueType", "int16", value: marker == chunk.wwiseMarkers.last ? "1" : "2"),
          WwiseProperty("TimeMs", "Real64", value: marker.fPosition.toString()),
        ]
      ).toXml();
    }).toList()));
  }
}
