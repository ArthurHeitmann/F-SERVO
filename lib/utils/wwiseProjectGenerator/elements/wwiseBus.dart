
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseUtils.dart';

Future<void> saveBusesIntoWu(WwiseProjectGenerator project) async {
  var masterBusHash = fnvHash("Master Audio Bus");
  Set<int> usedBusIds = {};
  usedBusIds.add(masterBusHash);
  for (var chunk in project.hircChunksByType<BnkHircChunkWithBaseParamsGetter>()) {
    var baseParams = chunk.value.getBaseParams();
    var busId = baseParams.overrideBusID;
    if (busId == 0)
      continue;
    usedBusIds.add(busId);
  }
  for (var actionC in project.hircChunksByType<BnkAction>()) {
    var action = actionC.value;
    if (action.initialParams.isBus)
      usedBusIds.add(action.initialParams.idExt);
    var actionType = actionTypes[action.type];
    if (actionType == null)
      continue;
    if (!actionType.contains("Bus"))
      continue;
    var targetId = action.initialParams.idExt;
    if (targetId == 0)
      continue;
    usedBusIds.add(targetId);
  }

  var wu = project.mmhWu;
  assert (wu.defaultChildren.length == 1);
  var childList = wu.defaultChildren[0];
  wu.defaultChildren.clear();
  var defaultBuses = childList.childElements
    .map((e) => WwiseElement.fromXml(wu.id, project, e))
    .toList();
  var masterAudioBus = defaultBuses[0];
  assert (masterAudioBus.tagName == "Bus");
  assert (masterAudioBus.name == "Master Audio Bus");
  for (var busId in usedBusIds) {
    WwiseElement bus;
    if (busId != masterBusHash) {
      bus = WwiseElement(
        wuId: wu.id,
        project: project,
        tagName: "Bus",
        name: wwiseIdToStr(busId),
        shortIdHint: busId,
      );
      masterAudioBus.addChild(bus);
    }
    else
      bus = project.defaultBus;
    project.buses[busId] = bus;
  }
  masterAudioBus.sortChildren((a, b) => a.name.compareTo(b.name));
  wu.addAllChildren(defaultBuses);
  await wu.save();
}
