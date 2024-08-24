
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseBlendContainer.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'wwiseActorMixer.dart';
import 'wwiseBusRouting.dart';
import 'wwiseConversionInfo.dart';
import 'wwiseEffect.dart';
import 'wwiseMusicPlaylist.dart';
import 'wwiseMusicSegment.dart';
import 'wwiseMusicSwitch.dart';
import 'wwiseMusicTrack.dart';
import 'wwisePositioningInfo.dart';
import 'wwiseRandomSequenceContainer.dart';
import 'wwiseSound.dart';
import 'wwiseStateInfo.dart';
import 'wwiseSwitchContainer.dart';

const _propIdToConfig = {
  0x00: (name: "Volume", type: "Real64"),
  0x02: (name: "Pitch", type: "int32"),
  0x03: (name: "Lowpass", type: "int16"),
  0x05: (name: "Priority", type: "Real64"),
  0x06: (name: "PriorityDistanceOffset", type: "int16"),
  0x07: (name: "LoopCount", type: "int32"),
  0x0d: (name: "DivergenceCenter", type: "int32"),
  0x16: (name: "GameAuxSendVolume", type: "Real64"),
  0x17: (name: "OutputBusVolume", type: "Real64"),
  0x18: (name: "OutputBusLowpass", type: "int16"),
};
const _pannerPropIdToConfig = {
  0x0b: (name: "PanX", type: "Real64"),
  0x0c: (name: "PanY", type: "Real64"),
};
const _rtpcPropIdToName = {
  0x00: (name: "Volume", type: "Real64"),
  0x02: (name: "Pitch", type: "int32"),
  0x03: (name: "Lowpass", type: "int16"),
  0x08: (name: "Priority", type: "int16"),
  0x09: (name: "MaxSoundPerInstance", type: "int16"),
  0x0F: (name: "UserAuxSendVolume0", type: "Real64"),
  0x10: (name: "UserAuxSendVolume1", type: "Real64"),
  0x11: (name: "UserAuxSendVolume2", type: "Real64"),
  0x12: (name: "UserAuxSendVolume3", type: "Real64"),
  0x13: (name: "GameAuxSendVolume", type: "Real64"),
  0x16: (name: "OutputBusVolume", type: "Real64"),
  0x17: (name: "OutputBusLowpass", type: "int16"),
  0x18: (name: "BypassEffect0", type: "bool"),
  0x19: (name: "BypassEffect1", type: "bool"),
  0x1A: (name: "BypassEffect2", type: "bool"),
  0x1B: (name: "BypassEffect3", type: "bool"),
  0x1C: (name: "BypassEffect", type: "bool"),
};

class WwiseHierarchyElement<T extends BnkHircChunkWithBaseParamsGetter> extends WwiseElement {
  final T chunk;

  WwiseHierarchyElement({required super.wuId, required super.project, required super.tagName, required super.name, required this.chunk, super.shortId, super.properties, super.additionalAttributes, super.children});

  @override
  @mustCallSuper
  void oneTimeInit() {
    super.oneTimeInit();
    var baseParams = chunk.getBaseParams();
    if (baseParams.overrideBusID != 0 && baseParams.directParentID != 0)
      properties.add(WwiseProperty("OverrideOutput", "bool", value: "True"));
    if (baseParams.bPriorityOverrideParent != 0)
      properties.add(WwiseProperty("OverridePriority", "bool", value: "True"));
    if (baseParams.bPriorityApplyDistFactor != 0)
      properties.add(WwiseProperty("PriorityDistanceFactor", "bool", value: "True"));
    var positioning = baseParams.positioning;
    if (positioning.uByVector & 1 != 0 && baseParams.directParentID != 0)
      properties.add(WwiseProperty("OverridePositioning", "bool", value: "True"));
    if (positioning.cbIs3DPositioningAvailable == 1)
      properties.add(WwiseProperty("PositioningType", "int16", value: "1"));
    if (positioning.bIsPannerEnabled == 1) {
      properties.add(WwiseProperty("EnablePanner", "bool", value: "True"));
    }
    if (positioning.eType_ == 2)
      properties.add(WwiseProperty("3DPositionSource", "int16", value: "0"));
    if (positioning.bIsSpatialized == 0)
      properties.add(WwiseProperty("Spatialization", "bool", value: "False"));
    if (positioning.bIsDynamic == 0)
      properties.add(WwiseProperty("DynamicPositioning", "bool", value: "False"));
    if (positioning.bFollowOrientation == 0)
      properties.add(WwiseProperty("FollowListenerOrientation", "bool", value: "False"));
    var aux = baseParams.auxParam;
    if (aux.bOverrideGameAuxSends != 0)
      properties.add(WwiseProperty("OverrideGameAuxSends", "bool", value: "True"));
    if (aux.bUseGameAuxSends != 0)
      properties.add(WwiseProperty("UseGameAuxSends", "bool", value: "True"));
    if (aux.bOverrideUserAuxSends != 0)
      properties.add(WwiseProperty("OverrideUserAuxSends", "bool", value: "True"));
    var adv = baseParams.advSettings;
    if (adv.bIsMaxNumInstOverrideParent != 0)
      properties.add(WwiseProperty("OverrideMaxSoundInstance", "bool", value: "True"));
    if (adv.u16MaxNumInstance != 50 || adv.bIsGlobalLimit != 0)
      properties.add(WwiseProperty("UseMaxSoundPerInstance", "bool", values: ["True"]));
    if (adv.u16MaxNumInstance != 50)
      properties.add(WwiseProperty("MaxSoundPerInstance", "int16", values: [adv.u16MaxNumInstance.toString()]));
    if (adv.bIsGlobalLimit != 0)
      properties.add(WwiseProperty("IsGlobalLimit", "int16", value: "1"));
    if (adv.bUseVirtualBehavior != 0)
      properties.add(WwiseProperty("OverLimitBehavior", "int16", value: "1"));
    if (adv.bKillNewest != 0)
      properties.add(WwiseProperty("MaxReachedBehavior", "int16", value: "1"));
    if (adv.bIsVVoicesOptOverrideParent != 0)
      properties.add(WwiseProperty("OverrideVirtualVoice", "bool", value: "True"));
    if (adv.eBelowThresholdBehavior != 0)
      properties.add(WwiseProperty("BelowThresholdBehavior", "int16", value: adv.eBelowThresholdBehavior.toString()));
    if (adv.eVirtualQueueBehavior != 1)
      properties.add(WwiseProperty("VirtualVoiceQueueBehavior", "int16", value: adv.eVirtualQueueBehavior.toString()));

    BnkMusicNodeParams? musicParams;
    if (chunk is BnkMusicSwitch)
      musicParams = (chunk as BnkMusicSwitch).musicTransParams.musicParams;
    else if (chunk is BnkMusicPlaylist)
      musicParams = (chunk as BnkMusicPlaylist).musicTransParams.musicParams;
    else if (chunk is BnkMusicSegment)
      musicParams = (chunk as BnkMusicSegment).musicParams;
    if (musicParams != null && musicParams.bMeterInfoFlag != 0) {
      if (baseParams.directParentID != 0)
        properties.add(WwiseProperty("OverrideClockSettings", "bool", value: "True"));
      var meterInfo = musicParams.meterInfo;
      if (meterInfo.fTempo != 120)
        properties.add(WwiseProperty("Tempo", "Real64", value: meterInfo.fTempo.toString()));
      if (meterInfo.uBeatValue != 4)
        properties.add(WwiseProperty("TimeSignatureLower", "int16", value: meterInfo.uBeatValue.toString()));
      if (meterInfo.uNumBeatsPerBar != 4)
        properties.add(WwiseProperty("TimeSignatureUpper", "int16", value: meterInfo.uNumBeatsPerBar.toString()));
      var frequencyPreset = determineMeterPreset(meterInfo, meterInfo.fGridPeriod);
      var offsetPreset = determineMeterPreset(meterInfo, meterInfo.fGridOffset);
      if (frequencyPreset != 50)
        properties.add(WwiseProperty("GridFrequencyPreset", "int16", value: frequencyPreset.toString()));
      if (offsetPreset != 0)
        properties.add(WwiseProperty("GridOffsetPreset", "int16", value: offsetPreset.toString()));
    }

    var valueProps = Iterable.generate(baseParams.iniParams.propValues.cProps)
      .map((i) => (baseParams.iniParams.propValues.pID[i], baseParams.iniParams.propValues.values[i]));
    var rangedProps = Iterable.generate(baseParams.iniParams.rangedPropValues.cProps)
      .map((i) => (baseParams.iniParams.rangedPropValues.pID[i], baseParams.iniParams.rangedPropValues.minMax[i]));
    List<WwiseProperty> pannerProps = [];
    for (var (propId, value) in valueProps) {
      var prop = _propIdToConfig[propId];
      if (prop == null) {
        if (_pannerPropIdToConfig.containsKey(propId)) {
          prop = _pannerPropIdToConfig[propId]!;
          pannerProps.add(WwiseProperty(prop.name, prop.type, value: value.number.toString()));
        }
        else {
          project.log(WwiseLogSeverity.warning, "Unknown property id $propId on ${chunk.uid}");
        }
        continue;
      }
      properties.add(WwiseProperty(prop.name, prop.type, value: value.number.toString()));
    }
    for (var (propId, value) in rangedProps) {
      var prop = _propIdToConfig[propId];
      if (prop == null) {
        project.log(WwiseLogSeverity.warning, "Unknown ranged property id $propId on ${chunk.uid}");
        continue;
      }
      properties.add(WwiseProperty(
        prop.name,
        prop.type,
        project: project,
        modifierRange: (min: value.$1.number.toString(), max: value.$2.number.toString())
      ));
    }
    for (var rtpc in baseParams.rtpc.rtpc) {
      var prop = _rtpcPropIdToName[rtpc.paramID];
      if (prop == null) {
        project.log(WwiseLogSeverity.warning, "Unknown rtpc id ${rtpc.paramID} on ${chunk.uid}");
        continue;
      }
      properties.add(WwiseProperty(prop.name, prop.type, project: project, rtpcs: [rtpc]));
    }

    additionalChildren.add(WwiseBusRouting.fromHirc(project, chunk).toXml());

    if (baseParams.fxParams.bIsOverrideParentFX != 0 && baseParams.directParentID != 0)
      properties.add(WwiseProperty("OverrideEffect", "bool", value: "True"));
    if (baseParams.fxParams.uNumFX > 0) {
      List<XmlElement> effects = [];
      for (var effect in baseParams.fxParams.effect) {
        if (effect.fxID == 0)
          continue;
        var effectRef = project.lookupElement(idFnv: effect.fxID) as WwiseEffect?;
        if (effectRef == null) {
          project.log(WwiseLogSeverity.warning, "Could not locate effect id ${effect.fxID}");
          continue;
        }
        if (effect.bIsShareSet != 0)
          effects.add(effectRef.asRef(effect.uFXIndex));
        else
          effects.add(effectRef.asCustomEffect(effect.uFXIndex));
        var bypassMask = 1 << effect.uFXIndex;
        var isBypass = baseParams.fxParams.bitsFXBypass! & bypassMask != 0;
        if (isBypass)
          properties.add(WwiseProperty("BypassEffect${effect.uFXIndex}", "bool", values: ["True"]));
        if (effect.bIsRendered != 0)
          properties.add(WwiseProperty("RenderEffect${effect.uFXIndex}", "bool", values: ["True"]));
      }
      additionalChildren.add(XmlElement(XmlName("EffectInfo"), [], effects));
    }

    var positioningInfo = makeWwisePositioningInfo(project, this, positioning, pannerProps);
    if (positioningInfo != null) {
      additionalChildren.add(positioningInfo);
    }

    var stateInfo = makeWwiseStatInfo(project, baseParams.states.stateGroup);
    if (stateInfo != null)
      additionalChildren.add(stateInfo);

    if (T != BnkMusicTrack)
      additionalChildren.add(WwiseConversionInfo.projectDefault(project).toXml());
  }
}

Future<void> saveHierarchyBaseElements(WwiseProjectGenerator project) async {
  var amhWu = project.amhWu;
  var imhWu = project.imhWu;
  Map<int, (int id, int parentId, WwiseHierarchyElement element)> amhElements = {};
  Map<int, (int id, int parentId, WwiseHierarchyElement element)> imhElements = {};
  for (var chunk in project.hircChunksByType<BnkHircChunkWithBaseParamsGetter>()) {
    var baseParams = chunk.getBaseParams();
    var id = (chunk as BnkHircChunkBase).uid;
    var parent = baseParams.directParentID;
    WwiseHierarchyElement? element;
    bool isAmh = false;
    if (chunk is BnkActorMixer) {
      element = WwiseActorMixer(project: project, wuId: amhWu.id, chunk: chunk);
      isAmh = true;
    }
    else if (chunk is BnkSound) {
      element = WwiseSound(project: project, wuId: amhWu.id, chunk: chunk);
      isAmh = true;
    }
    else if (chunk is BnkRandomSequence) {
      element = RandomSequenceContainer(project: project, wuId: amhWu.id, chunk: chunk);
      isAmh = true;
    }
    else if (chunk is BnkSoundSwitch) {
      var children = amhElements
        .values
        .where((e) => e.$2 == id)
        .map((e) => e.$3)
        .toList();
      element = WwiseSwitchContainer(project: project, wuId: amhWu.id, chunk: chunk, childElements: children);
      isAmh = true;
    }
    else if (chunk is BnkLayerContainer) {
      element = WwiseBlendContainer(project: project, wuId: amhWu.id, chunk: chunk);
      isAmh = true;
    }
    else if (chunk is BnkMusicTrack) {
      element = WwiseMusicTrack(project: project, wuId: imhWu.id, chunk: chunk);
    }
    else if (chunk is BnkMusicSegment) {
      element = WwiseMusicSegment(project: project, wuId: imhWu.id, chunk: chunk);
    }
    else if (chunk is BnkMusicPlaylist) {
      element = WwiseMusicPlaylist(project: project, wuId: imhWu.id, chunk: chunk);
    }
    else if (chunk is BnkMusicSwitch) {
      element = WwiseMusicSwitch(project: project, wuId: imhWu.id, chunk: chunk);
    }
    else {
      project.log(WwiseLogSeverity.warning, "Unknown chunk type ${chunk.runtimeType}");
    }

    if (element != null) {
      if (isAmh) {
        amhElements[id] = (id, parent, element);
      } else {
        imhElements[id] = (id, parent, element);
      }
    }
  }

  var hierarchies = [
    (amhWu, amhElements),
    (imhWu, imhElements),
  ];
  for (var (workUnit, elements) in hierarchies) {
    for (var (id, parentId, element) in elements.values) {
      var parent = elements[parentId];
      if (parent == null && parentId != 0) {
        project.log(WwiseLogSeverity.warning, "Could not find parent $parentId for $id");
        continue;
      }
      if (parent != null)
        parent.$3.children.add(element);
      else
        workUnit.addChild(element, id);
    }
    for (var child in workUnit.children) {
      child.oneTimeInit();
    }
    await workUnit.save();
  }
}
