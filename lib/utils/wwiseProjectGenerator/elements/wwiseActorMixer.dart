
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';

class WwiseActorMixer extends WwiseHierarchyElement<BnkActorMixer> {
  WwiseActorMixer({required super.wuId, required super.project, required super.chunk}) :
    super(tagName: "ActorMixer", name: wwiseIdToStr(chunk.uid, fallbackPrefix: "Actor Mixer"), shortId: chunk.uid);
}
