
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';

class WwiseActorMixer extends WwiseHierarchyElement<BnkActorMixer> {
  WwiseActorMixer({required super.wuId, required super.project, required super.chunk}) :
    super(tagName: "ActorMixer", shortId: chunk.uid);

  @override
  String getFallbackName() {
    return makeElementName(
      project,
      id: newShortId!,
      parentId: chunk.baseParams.directParentID,
      category: "Actor Mixer",
      name: guessed.name.value,
    );
  }
}
