
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseUtils.dart';
import 'wwiseSwitchOrState.dart';

Future<void> saveSwitchesIntoWu(WwiseProjectGenerator project) async {
  Map<int, Set<int>> usedSwitchGroupIds = {};
  for (var musicSwitch in project.hircChunksByType<BnkMusicSwitch>()) {
    addWwiseGroupUsage(usedSwitchGroupIds, musicSwitch.ulGroupID, musicSwitch.ulDefaultSwitch);
    for (var switchAssoc in musicSwitch.pAssocs) {
      addWwiseGroupUsage(usedSwitchGroupIds, musicSwitch.ulGroupID, switchAssoc.switchID);
    }
  }
  for (var musicSwitch in project.hircChunksByType<BnkSoundSwitch>()) {
    addWwiseGroupUsage(usedSwitchGroupIds, musicSwitch.ulGroupID, musicSwitch.ulDefaultSwitch);
    for (var switchAssoc in musicSwitch.switches) {
      addWwiseGroupUsage(usedSwitchGroupIds, musicSwitch.ulGroupID, switchAssoc.ulSwitchID);
    }
  }
  for (var action in project.hircChunksByType<BnkAction>()) {
    var params = action.specificParams;
    if (params is BnkSwitchActionParams) {
      addWwiseGroupUsage(usedSwitchGroupIds, params.ulSwitchGroupID, params.ulSwitchStateID);
    }
  }
  
  List<(int, WwiseElement)> switchGroups = usedSwitchGroupIds.entries
    .map((e) {
      var switchGroupId = e.key;
      var switchElementsAndIds = e.value
        .map((id) => (
          WwiseElement(
            wuId: project.switchesWu.id,
            project: project,
            tagName: "Switch",
            name: wwiseIdToStr(id),
            shortIdHint: id,
          ),
          id
        ))
        .toList()
        ..sort((a, b) => a.$1.name.compareTo(b.$1.name));
      var switchGroupElement = WwiseElement(
        wuId: project.switchesWu.id,
        project: project,
        tagName: "SwitchGroup",
        name: wwiseIdToStr(switchGroupId),
        shortIdHint: switchGroupId,
        children: switchElementsAndIds.map((e) => e.$1).toList(),
      );
      var switchGroup = WwiseSwitchOrStateGroup(
        switchGroupId,
        switchGroupElement.id,
        switchGroupElement.name,
        switchElementsAndIds
          .map((e) => WwiseSwitchOrState(e.$2, e.$1.id, e.$1.name))
          .toList()
      );
      project.switchGroups[switchGroupId] = switchGroup;
      return (switchGroupId, switchGroupElement);
    })
    .toList()
    ..sort((a, b) => a.$2.name.compareTo(b.$2.name));

  for (var (id, group) in switchGroups)
    project.switchesWu.addChild(group, id);
  await project.switchesWu.save();
}
