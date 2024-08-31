
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../../fileTypeUtils/audio/wwiseObjectPath.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';
import 'wwiseAudioFileSource.dart';
import 'wwiseSourcePlugin.dart';

const _loopPropId = 0x07;

class WwiseSound extends WwiseHierarchyElement<BnkSound> {
  WwiseSound({required super.wuId, required super.project, required super.chunk, required String language}) : super(
    tagName: "Sound",
    shortId: chunk.uid,
    additionalAttributes: { "Type": chunk.bankData.mediaInformation.uSourceBits & 1 == 0 ? "SoundFX" : "Voice"},
    properties: [
      if (project.options.streaming && chunk.bankData.streamType >= 1)
        WwiseProperty("IsStreamingEnabled", "bool", values: ["True"]),
      if (project.options.streaming && project.options.streamingPrefetch && chunk.bankData.streamType == 2)
        WwiseProperty("IsZeroLantency", "bool", values: ["True"]),
    ],
    children: [
      if (chunk.bankData.mediaInformation.uFileID == 0 && WwiseSourcePlugin.isSourcePlugin(project, chunk.bankData.mediaInformation.sourceID))
        WwiseSourcePlugin(wuId: wuId, project: project, fxId: chunk.bankData.mediaInformation.sourceID, language: language)
      else if (project.soundFiles.containsKey(chunk.bankData.mediaInformation.sourceID))
        WwiseAudioFileSource(wuId: wuId, project: project, audio: project.soundFiles[chunk.bankData.mediaInformation.sourceID]!),
    ],
  ) {
    var loopProp = chunk.baseParams.iniParams.propValues.props
      .where((p) => p.$1 == _loopPropId)
      .map((p) => p.$2)
      .firstOrNull;
    loopProp ??= chunk.baseParams.iniParams.rangedPropValues.pID
      .where((pId) => pId == _loopPropId)
      .isNotEmpty ? 1 : null;
    if (loopProp != null) {
      properties.add(WwiseProperty("IsLoopingEnabled", "bool", value: "True"));
      if (loopProp == 0)
        properties.add(WwiseProperty("IsLoopingInfinite", "bool", value: "True"));
    }
  }

  @override
  String getFallbackName() {
    return makeElementName(project,
      id: newShortId!,
      category: "Sound",
      name: guessed.name.value ?? wemIdsToNames[chunk.uid] ?? wemIdsToNames[chunk.bankData.mediaInformation.sourceID],
      parentId: chunk.baseParams.directParentID,
    );
  }

  @override
  void initNames() {
    if (chunk.bankData.streamType == 0 || chunk.bankData.streamType == 2)
      addGuessedFullPathFromId(inMemoryAudioBnkToIdObjectPath, chunk.bankData.mediaInformation.sourceID, false);
    else if (chunk.bankData.streamType == 1)
      addGuessedFullPathFromId(streamedAudioBnkToIdObjectPath, chunk.bankData.mediaInformation.sourceID, false);
    super.initNames();
  }
  
  @override
  void initData() {
    super.initData();
    var audioSource = children.firstOrNull;
    if (audioSource != null) {
      additionalChildren.add(makeXmlElement(name: "ActiveSourceList", children: [WwiseElement(
        wuId: wuId,
        project: project,
        tagName: "ActiveSource",
        name: audioSource.name,
        id: audioSource.id,
        additionalAttributes: { "Platform": "Linked"},
      ).toXml()]));
    }
  }
}
