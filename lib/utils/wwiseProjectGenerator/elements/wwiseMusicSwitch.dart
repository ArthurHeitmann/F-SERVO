
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../utils.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';
import 'wwiseSwitchOrState.dart';
import 'wwiseTransitionList.dart';
import 'wwiseTriggers.dart';

class WwiseMusicSwitch extends WwiseHierarchyElement<BnkMusicSwitch> {
  WwiseMusicSwitch({required super.wuId, required super.project, required super.chunk}) :
    super(
      tagName: "MusicSwitchContainer",
      shortId: chunk.uid,
      properties: [
        if (chunk.bIsContinuousValidation != 1)
          WwiseProperty("ContinuePlay", "bool", value: "False"),
      ]
    );

  @override
  String getFallbackName() {
    return makeElementName(project,
      id: chunk.uid,
      parentId: chunk.getBaseParams().directParentID,
      name: guessed.name.value ?? wemIdsToNames[chunk.ulGroupID],
      category: "Music Switch Container",
    );
  }
  
  @override
  void initData() {
    super.initData();
    additionalChildren.add(makeWwiseTransitionList(project, wuId, chunk.musicTransParams.rules));
    var stingerList = makeStingerList(project, wuId, chunk.musicTransParams.musicParams.stingers);
    if (stingerList != null)
      additionalChildren.add(stingerList);
    WwiseSwitchOrStateGroup? group;
    if (chunk.eGroupType == 0) {  // switch
      group = project.switchGroups[chunk.ulGroupID];
    } else {  // state
      group = project.stateGroups[chunk.ulGroupID];
    }
    var groupChild = group?.children.where((c) => c.id == chunk.ulDefaultSwitch).firstOrNull;
    additionalChildren.add(makeXmlElement(name: "GroupingInfo", children: [
      makeXmlElement(name: "GroupRef", attributes: {"Name": group?.name ?? "", "ID": group?.uuid ?? wwiseNullId}),
      makeXmlElement(name: "DefaultSwitchRef", attributes: {"Name": groupChild?.name ?? "", "ID": groupChild?.uuid ?? wwiseNullId}),
      if (chunk.pAssocs.isNotEmpty)
        makeXmlElement(name: "GroupingList", children: chunk.pAssocs.map((sw) {
            var groupChild = group?.children.where((c) => c.id == sw.switchID).firstOrNull;
            var child = project.lookupElement(idFnv: sw.nodeID);
            return makeXmlElement(name: "Grouping", children: [
              makeXmlElement(name: "SwitchRef", attributes: {"Name": groupChild?.name ?? "", "ID": groupChild?.uuid ?? wwiseNullId}),
              makeXmlElement(name: "ChildRef", attributes: {"Name": child?.name ?? "", "ID": child?.id ?? wwiseNullId}),
            ]);
          }).toList()),
    ]));
  }
}
