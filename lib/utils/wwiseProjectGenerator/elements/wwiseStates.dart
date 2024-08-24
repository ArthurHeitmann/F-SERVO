
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseUtils.dart';
import 'wwiseSwitchOrState.dart';


Future<void> saveStatesIntoWu(WwiseProjectGenerator project) async {
  Map<int, Set<int>> usedStateGroupIds = {};
  for (var baseChunk in project.hircChunksByType<BnkHircChunkWithBaseParamsGetter>()) {
    var baseParams = baseChunk.getBaseParams();
    for (var stateGroup in baseParams.states.stateGroup) {
      for (var state in stateGroup.state) {
        addWwiseGroupUsage(usedStateGroupIds, stateGroup.ulStateGroupID, state.ulStateID);
      }
    }
  }
  for (var action in project.hircChunksByType<BnkAction>()) {
    var actionParams = action.specificParams;
    if (actionParams is BnkStateActionParams) {
      addWwiseGroupUsage(usedStateGroupIds, actionParams.ulStateGroupID, actionParams.ulTargetStateID);
    }
  }
  
  var noneHash = fnvHash("None");
  List<(int, WwiseElement)> stateGroups = usedStateGroupIds.entries
    .map((e) {
      var stateGroupId = e.key;
      var states = e.value;
      states.add(noneHash);
      var sortedStates = states.toList()..sort((a, b) {
        if (a == noneHash) return -1;
        if (b == noneHash) return 1;
        return a.compareTo(b);
      });
      var stateElements = sortedStates
        .map((id) => WwiseElement(
          wuId: project.statesWu.id,
          project: project,
          tagName: "State",
          name: wwiseIdToStr(id),
          shortIdHint: id,
        ))
        .toList();
      var stateGroupElement = WwiseElement(
        wuId: project.statesWu.id,
        project: project,
        tagName: "StateGroup",
        name: wwiseIdToStr(e.key),
        shortIdHint: e.key,
        children: stateElements,
      );
      var stateGroup = WwiseSwitchOrStateGroup(
        e.key,
        stateGroupElement.id,
        stateGroupElement.name,
        stateElements.indexed
          .map((e) => WwiseSwitchOrState(sortedStates[e.$1], e.$2.id, e.$2.name))
          .toList()
      );
      project.stateGroups[stateGroupId] = stateGroup;
      return (stateGroupId, stateGroupElement);
    })
    .toList()
    ..sort((a, b) => a.$2.name.compareTo(b.$2.name));

  for (var (id, group) in stateGroups)
    project.statesWu.addChild(group, id);
  await project.statesWu.save();
}
