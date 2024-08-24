
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseElement.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';

const _bnkTransitionTypeToWwu = {
  1: 0,
  2: 4,
  3: 1,
  4: 2,
  5: 3,
};

class RandomSequenceContainer extends WwiseHierarchyElement<BnkRandomSequence> {
  RandomSequenceContainer({required super.wuId, required super.project, required super.chunk}) :
    super(
      tagName: "RandomSequenceContainer",
      name: makeElementName(project, id: chunk.uid, category: chunk.eMode == 1 ? "Sequence Container" : "Random Container", parentId: chunk.baseParams.directParentID, childIds: chunk.childrenList.ulChildIDs, addId: true),
      shortId: chunk.uid,
      properties: [
        // play type
        WwiseProperty("RandomOrSequence", "int16", value: chunk.eMode == 0 ? "1" : "0"),
        // play type - random
        WwiseProperty("NormalOrShuffle", "int16", value: chunk.eRandomMode == 0 ? "1" : "0"),
        if (chunk.wAvoidRepeatCount > 1)
          WwiseProperty("RandomAvoidRepeatingCount", "int32", value: chunk.wAvoidRepeatCount.toString())
        else if (chunk.wAvoidRepeatCount == 0)
          WwiseProperty("RandomAvoidRepeating", "bool", value: "False"),
        // play type - chunk
        if (chunk.bIsRestartBackward == 1)
          WwiseProperty("RestartBeginningOrBackward", "int16", value: "0"),
        // play mode
        if (chunk.bIsContinuous == 1)
          WwiseProperty("PlayMechanismStepOrContinuous", "int16", value: "0"),
        if (chunk.bResetPlayListAtEachPlay == 0)
          WwiseProperty("PlayMechanismResetPlaylistEachPlay", "bool", value: "False"),
        // play mode - loop
        if (chunk.sLoopCount != 1)
          WwiseProperty("PlayMechanismLoop", "bool", value: "True"),
        if (chunk.sLoopCount > 2) ...[
          WwiseProperty("PlayMechanismLoopCount", "int16", value: chunk.sLoopCount.toString()),
          WwiseProperty("PlayMechanismInfiniteOrNumberOfLoops", "int16", value: "0"),
        ],
        // play mode - transitions
        if (chunk.eTransitionMode != 0)
          WwiseProperty("PlayMechanismSpecialTransitions", "bool", value: "True"),
        if (chunk.eTransitionMode != 0)
          WwiseProperty("PlayMechanismSpecialTransitionsType", "int16", value: _bnkTransitionTypeToWwu[chunk.eTransitionMode]!.toString()),
        if (chunk.fTransitionTime / 1000 != 1.0)
          WwiseProperty("PlayMechanismSpecialTransitionsValue", "Real64", value: (chunk.fTransitionTime / 1000).toString()),
        if (chunk.fTransitionTimeModMin != 0.0 || chunk.fTransitionTimeModMax != 0.0)
          WwiseProperty(
            "PlayMechanismSpecialTransitionsValue",
            "Real64",
            project: project,
            modifierRange: (min: (chunk.fTransitionTimeModMin / 1000).toString(), max: (chunk.fTransitionTimeModMax / 1000).toString()),
          ),
        // scope
        if (chunk.bIsGlobal == 0)
          WwiseProperty("GlobalOrPerObject", "int16", value: "0"),
      ]
    );
  
  @override
  void oneTimeInit() {
    super.oneTimeInit();
    for (var plItem in chunk.playlistItems) {
      if (plItem.weight == 50000)
        continue;
      var child = project.lookupElement(idFnv: plItem.ulPlayID);
      if (child is! WwiseElement)
        continue;
      child.properties.add(WwiseProperty("Weight", "Real64", values: [(plItem.weight / 1000).toString()]));
    }
  }
}
