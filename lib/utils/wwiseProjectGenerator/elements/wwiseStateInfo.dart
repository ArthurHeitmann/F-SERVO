
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseProjectGenerator.dart';
import 'wwiseSwitchOrState.dart';

const _propIdToName = {
  0x00: (name: "Volume", type: "Real64"),
  0x02: (name: "Pitch", type: "int32"),
  0x03: (name: "Lowpass", type: "int16"),
};

XmlElement? makeWwiseStatInfo(WwiseProjectGenerator project, List<BnkStateChunkGroup> states) {
  var usedStateGroups = states
    .map((s) => s.ulStateGroupID)
    .map((id) {
      var group = project.stateGroups[id];
      if (group == null)
        project.log(WwiseLogSeverity.warning, "State group $id is not found");
      return group;
    })
    .whereType<WwiseSwitchOrStateGroup>()
    .toList();
  if (usedStateGroups.isEmpty)
    return null;
  var usedStates = {
    for (var group in usedStateGroups)
      group.id: {
        for (var state in group.children)
          state.id: state,
      },
  };

  var stateGroupInfos = [
    for (var group in usedStateGroups)
      makeXmlElement(name: "StateGroupInfo", children: [
        makeXmlElement(name: "StateGroupRef", attributes: {"Name": group.name, "ID": group.uuid}),
      ])
  ];
  List<XmlElement> customStates = [];
  for (var stateGroup in states) {
    for (var state in stateGroup.state) {
      var stateRef = usedStates[stateGroup.ulStateGroupID]![state.ulStateID]!;
      var stateChunk = project.bnkStateChunks[state.ulStateInstanceID]!;
      customStates.add(
        makeXmlElement(name: "CustomState", children: [
          makeXmlElement(name: "StateRef", attributes: {"Name": stateRef.name, "ID": stateRef.uuid}),
          makeXmlElement(name: "State", attributes: {"Name": "Custom state", "ID": project.idGen.uuid(), "ShortID": project.idGen.shortId().toString()}, children: [
            makeXmlElement(name: "PropertyList", children: stateChunk.props.props
              .map((prop) {
                var propInfo = _propIdToName[prop.$1];
                if (propInfo == null) {
                  project.log(WwiseLogSeverity.warning, "Unknown property ${prop.$1}");
                  return null;
                }
                return makeXmlElement(name: "Property", attributes: {"Name": propInfo.name, "Type": propInfo.type, "Value": prop.$2.toString()});
              })
              .whereType<XmlElement>()
              .toList(),
            ),
          ]),
        ]),
      );
    }
  }

  return makeXmlElement(name: "StateInfo", children: [
    makeXmlElement(name: "StateGroupList", children: stateGroupInfos),
    if (customStates.isNotEmpty)
      makeXmlElement(name: "CustomStateList", children: customStates),
  ]);
}
