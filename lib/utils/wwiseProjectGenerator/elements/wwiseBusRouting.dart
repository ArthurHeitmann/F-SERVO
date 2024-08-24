
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';

class WwiseBusRouting extends WwiseElement {
  WwiseBusRouting({required super.wuId, required super.project, required super.tagName, required super.name, required super.id});
  
  factory WwiseBusRouting.fromHirc(WwiseProjectGenerator project, BnkHircChunkWithBaseParamsGetter chunk) {
    var baseParams = chunk.getBaseParams();
    var busId = baseParams.overrideBusID;
    var bus = busId == 0
      ? project.defaultBus
      : project.buses[busId]!;
    return WwiseBusRouting(
      wuId: "",
      project: project,
      tagName: "BusRouting",
      name: bus.name,
      id: bus.id,
    );
  }
}
