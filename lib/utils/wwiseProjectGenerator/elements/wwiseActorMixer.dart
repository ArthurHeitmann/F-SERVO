
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';

class WwiseActorMixer extends WwiseHierarchyElement<BnkActorMixer> {
  WwiseActorMixer({required super.wuId, required super.project, required super.chunk}) :
    super(tagName: "ActorMixer", name: makeElementName(project, id: chunk.uid, parentId: chunk.baseParams.directParentID, category: "Actor Mixer"), shortId: chunk.uid);
}
