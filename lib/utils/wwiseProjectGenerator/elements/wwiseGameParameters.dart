
import 'dart:math';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';

Future<void> saveGameParametersIntoWu(WwiseProjectGenerator project) async {
  Set<int> usedGameParameterIds = {};
  Map<int, Set<String>> parameterIdToBnk = {};
  Map<int, ({double min, double max})> valueMinMax = {};
  Map<int, ({double min, double max})> graphMinMax = {};
  for (var chunk in project.hircChunksByType<BnkHircChunkWithBaseParamsGetter>()) {
    var baseParams = chunk.value.getBaseParams();
    for (var rtpc in baseParams.rtpc.rtpc) {
      usedGameParameterIds.add(rtpc.rtpcId);
      parameterIdToBnk.putIfAbsent(rtpc.rtpcId, () =>{}).addAll(chunk.names);
      var allX = rtpc.rtpcGraphPoint.map((e) => e.x).toList();
      var minX = allX.reduce((value, element) => value < element ? value : element);
      var maxX = allX.reduce((value, element) => value > element ? value : element);
      var minMax = graphMinMax[rtpc.rtpcId] ?? (min: double.infinity, max: double.negativeInfinity);
      graphMinMax[rtpc.rtpcId] = (min: min(minX, minMax.min), max: max(maxX, minMax.max));
    }
  }
  for (var actionC in project.hircChunksByType<BnkAction>()) {
    var action = actionC.value;
    var specificParams = action.specificParams;
    if (specificParams is BnkValueActionParams) {
      if (gameParamActionTypes.contains(action.ulActionType & 0xFF00)) {
        usedGameParameterIds.add(action.initialParams.idExt);
        parameterIdToBnk.putIfAbsent(action.initialParams.idExt, () => {}).addAll(actionC.names);
        var subParams = specificParams.specificParams;
        if (subParams is BnkGameParameterParams) {
          var value = subParams.base;
          var minMax = valueMinMax[action.initialParams.idExt] ?? (min: double.infinity, max: double.negativeInfinity);
          valueMinMax[action.initialParams.idExt] = (min: min(value, minMax.min), max: max(value, minMax.max));
        }
      }
    }
  }
  
  List<(int, WwiseElement)> gameParameters = usedGameParameterIds
    .map((id) {
      var valueMin = valueMinMax[id]?.min;
      var valueMax = valueMinMax[id]?.max;
      var graphMin = graphMinMax[id]?.min;
      var graphMax = graphMinMax[id]?.max;
      if (graphMin != null && valueMin != null)
        valueMin = min(valueMin, graphMin);
      if (graphMax != null && valueMax != null)
        valueMax = max(valueMax, graphMax);
      valueMin ??= graphMin;
      valueMax ??= graphMax;
      var parameter = WwiseElement(
        wuId: project.gameParametersWu.id,
        project: project,
        tagName: "GameParameter",
        name: wwiseIdToStr(id),
        shortIdHint: id,
        properties: [
          if (graphMax != null && graphMax != 100)
            WwiseProperty("Max", "Real64", value: graphMax.toString())
          else if (valueMax != null && valueMax > 100)
            WwiseProperty("Max", "Real64", value: valueMax.toString()),
          if (graphMin != null && graphMin != 0)
            WwiseProperty("Min", "Real64", value: graphMin.toString())
          else if (valueMin != null && valueMin < 0)
            WwiseProperty("Min", "Real64", value: valueMin.toString()),
        ]
      );
      project.gameParameters[id] = parameter;
      return (id, parameter);
    })
    .toList()
    ..sort((a, b) => a.$2.name.compareTo(b.$2.name));

  for (var (id, param) in gameParameters)
    project.gameParametersWu.addWuChild(param, id, parameterIdToBnk[id]!);
  await project.gameParametersWu.save();
}
