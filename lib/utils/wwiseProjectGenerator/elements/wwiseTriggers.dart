
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';

Future<void> saveTriggersIntoWu(WwiseProjectGenerator project) async {
  Set<int> usedTriggerIds = {};
  for (var chunk in project.hircChunks) {
    BnkMusicNodeParams? musicParams;
    if (chunk is BnkMusicSegment)
      musicParams = chunk.musicParams;
    else if (chunk is BnkMusicPlaylist)
      musicParams = chunk.musicTransParams.musicParams;
    else if (chunk is BnkMusicSwitch)
      musicParams = chunk.musicTransParams.musicParams;
    if (musicParams != null) {
      for (var stinger in musicParams.stingers)
        usedTriggerIds.add(stinger.triggerID);
    }
    if (chunk is BnkAction && chunk.type & 0xFF00 == 0x1D00) {
      usedTriggerIds.add(chunk.initialParams.idExt);
    }
  }
  
  List<(int, WwiseElement)> triggers = usedTriggerIds
    .map((id) {
      var trigger = WwiseElement(
        wuId: project.triggersWu.id,
        project: project,
        tagName: "Trigger",
        name: wwiseIdToStr(id),
        shortIdHint: id,
      );
      return (id, trigger);
    })
    .toList()
    ..sort((a, b) => a.$2.name.compareTo(b.$2.name));

  for (var (id, param) in triggers)
    project.triggersWu.addChild(param, id);
  await project.triggersWu.save();
}

XmlElement? makeStingerList(WwiseProjectGenerator project, String wuId, List<BnkAkStinger> stingers) {
  List<WwiseElement> stingerElements = [];
  for (var stinger in stingers) {
    var trigger = project.lookupElement(idFnv: stinger.triggerID)! as WwiseElement;
    WwiseElement? segment;
    if (stinger.segmentID != 0) {
      segment = project.lookupElement(idFnv: stinger.segmentID) as WwiseElement?;
      if (segment == null)
        project.log(WwiseLogSeverity.warning, "Stinger segment not found: ${stinger.segmentID}");
    }
    stingerElements.add(WwiseElement(
      project: project,
      wuId: wuId,
      tagName: "MusicStinger",
      name: "",
      properties: [
        if (stinger.syncPlayAt != 0)
          WwiseProperty("PlaySegmentAt", "int16", value: stinger.syncPlayAt.toString()),
        if (stinger.noRepeatTime != 0)
          WwiseProperty("DontPlayAgainTime", "Real64", value: (stinger.noRepeatTime / 1000).toString()),
        if (stinger.numSegmentLookAhead != 1)
          WwiseProperty("NumSegmentAdvance", "int16", value: stinger.numSegmentLookAhead.toString()),
      ],
      additionalChildren: [
        makeXmlElement(name: "TriggerRef", attributes: {
          "Name": trigger.name,
          "ID": trigger.id,
          "WorkUnitID": trigger.wuId,
        }),
        if (segment != null)
          makeXmlElement(name: "SegmentRef", attributes: {
            "Name": segment.name,
            "ID": segment.id,
            "WorkUnitID": segment.wuId,
          }),
      ]
    ));
  }
  if (stingerElements.isEmpty)
    return null;
  return makeXmlElement(name: "StingerList", children: stingerElements.map((e) => e.toXml()).toList());
}
