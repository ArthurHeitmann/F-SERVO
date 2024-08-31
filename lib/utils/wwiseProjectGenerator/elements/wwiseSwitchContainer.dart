
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';
import 'wwiseSwitchOrState.dart';

class WwiseSwitchContainer extends WwiseHierarchyElement<BnkSoundSwitch> {
  final List<WwiseElement> childElements;
  
  WwiseSwitchContainer({required super.wuId, required super.project, required super.chunk, required this.childElements}) : super(
    tagName: "SwitchContainer",
    shortId: chunk.uid,
    properties: [
      if (chunk.eGroupType == 1)
        WwiseProperty("GroupType", "int16", value: "1"),
      if (chunk.bIsContinuousValidation != 0)
        WwiseProperty("PlayMechanismStepOrContinuous", "int16", value: "0"),
    ]
  );

  @override
  String getFallbackName() {
    return makeElementName(project,
      id: newShortId!,
      parentId: chunk.baseParams.directParentID,
      name: guessed.name.value ?? wemIdsToNames[chunk.ulGroupID],
      category: "Switch Container",
    );
  }
  
  @override
  void initData() {
    super.initData();
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
      makeXmlElement(name: "GroupingBehaviorList", children: childElements.map((child) {
        var switchParams = chunk.switchParams
          .where((p) => p.ulNodeID == child.shortId!)
          .where(_isNonDefaultSwitchNodeParam)
          .firstOrNull;
        return makeXmlElement(
          name: "GroupingBehavior", children: [
            makeXmlElement(name: "ItemRef", attributes: {"Name": child.name, "ID": child.id}),
            if (switchParams != null)
              WwisePropertyList([
                if (switchParams.bIsFirstOnly != 0)
                  WwiseProperty("FirstOccurenceOnly", "bool", value: "True"),
                if (switchParams.bContinuePlayback != 0)
                  WwiseProperty("ContinuePlay", "bool", value: "True"),
                if (switchParams.fadeOutTime != 0)
                  WwiseProperty("FadeOutTime", "Real64", value: (switchParams.fadeOutTime / 1000).toString()),
                if (switchParams.fadeInTime != 0)
                  WwiseProperty("FadeInTime", "Real64", value: (switchParams.fadeInTime / 1000).toString()),
              ]).toXml()
          ]
        );
      }).toList()),
      if (chunk.switches.isNotEmpty)
        makeXmlElement(name: "GroupingList", children: chunk.switches
          .map((sw) {
            if (sw.nodeIDs.isEmpty)
              return null;
            var groupChild = group?.children.where((c) => c.id == sw.ulSwitchID).firstOrNull;
            return makeXmlElement(name: "Grouping", children: [
              makeXmlElement(name: "SwitchRef", attributes: {"Name": groupChild?.name ?? "", "ID": groupChild?.uuid ?? wwiseNullId}),
              makeXmlElement(name: "ItemList", children: sw.nodeIDs
                .map((id) {
                  var child = project.lookupElement(idFnv: id);
                  if (child == null || child is! WwiseElement)
                    return null;
                  return makeXmlElement(name: "ItemRef", attributes: {"Name": child.name, "ID": child.id});
                })
                .whereType<XmlElement>()
                .toList()
              ),
            ]);
          })
          .whereType<XmlElement>()
          .toList()
        ),
    ]));
  }
}

bool _isNonDefaultSwitchNodeParam(BnkSwitchNodeParam param) {
  return param.bIsFirstOnly != 0 || param.bContinuePlayback != 0 || param.fadeOutTime != 0 || param.fadeInTime != 0;
}
