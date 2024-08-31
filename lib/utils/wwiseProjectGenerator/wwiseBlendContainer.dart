

import '../../fileTypeUtils/audio/bnkIO.dart';
import 'elements/hierarchyBaseElements.dart';
import 'wwiseUtils.dart';

class WwiseBlendContainer extends WwiseHierarchyElement<BnkLayerContainer> {
  WwiseBlendContainer({required super.wuId, required super.project, required super.chunk}) : super(
    tagName: "BlendContainer",
    shortId: chunk.uid,
  );

  @override
  String getFallbackName() {
    return makeElementName(project,
      id: newShortId!,
      category: "Blend Container",
      parentId: chunk.baseParams.directParentID,
      childIds: chunk.childrenList.ulChildIDs,
      name: guessed.name.value,
    );
  }
}
