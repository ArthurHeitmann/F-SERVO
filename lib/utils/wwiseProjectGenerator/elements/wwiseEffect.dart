
// ignore_for_file: constant_identifier_names

import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';

typedef _PluginConfig = ({List<WwiseProperty> Function(BnkPluginData data) handler, String name, String pluginId, Map<int, ({String name, String type})> rtpcProps});
const Map<int, _PluginConfig> _pluginConfigs = {
  0x00760003: (name: "Wwise RoomVerb", pluginId: "118", handler: _getRoomVerbProperties, rtpcProps: _roomVerbRtpcProps),
};

const _ignorePluginIds = { 0x00640002, 0x00650002 };

class WwiseEffect extends WwiseElement {
  final BnkFxCustom effect;
  final _PluginConfig _config;

  WwiseEffect({required super.wuId, required super.project, required this.effect, required _PluginConfig config}) :
    _config = config,
    super(
      tagName: "Effect",
      name: makeElementName(project, id: effect.uid, category: "Effect"),
      shortId: effect.uid,
      shortIdType: ShortIdType.object,
      comment: project.getComment(effect.uid),
      properties: config.handler(effect.pluginData),
      additionalAttributes: {
        "PluginName": config.name,
        "CompanyID": "0",
        "PluginID": config.pluginId,
      },
    ) {
    for (var rtpc in effect.rtpc.rtpc) {
      var propConfig = config.rtpcProps[rtpc.paramID];
      if (propConfig == null) {
        project.log(WwiseLogSeverity.warning, "Unknown rtpc curve id ${rtpc.paramID} for effect plugin ${config.name}");
        continue;
      }
      properties.add(WwiseProperty(propConfig.name, propConfig.type, project: project, rtpcs: [rtpc]));
    }
  }

  static WwiseEffect? fromId({required String wuId, required WwiseProjectGenerator project, required int id}) {
    var effect = project.hircChunkById<BnkFxCustom>(id);
    if (effect == null) {
      project.log(WwiseLogSeverity.warning, "Could not locate effect id $id");
      return null;
    }
    var config = _pluginConfigs[effect.fxId];
    if (config == null) {
      project.log(WwiseLogSeverity.warning, "Unknown effect id ${effect.fxId}");
      return null;
    }
    return WwiseEffect(wuId: wuId, project: project, effect: effect, config: config);
  }

  XmlElement asRef(int index) {
    return makeXmlElement(
      name: "EffectRef",
      attributes: {
        "Name": name,
        "ID": id,
        "CompanyID": "0",
        "Index": index.toString(),
        "Platform": "Linked",
        "PluginID": _config.pluginId,
        "PluginName": _config.name,
      }
    );
  }

  XmlElement asCustomEffect(int index) {
    return makeXmlElement(
      name: "CustomEffect",
      attributes: {"Platform": "Linked", "Index": index.toString()},
      children: [toXml()],
    );
  }
}

class _RoomVerbProperties {
  static const CenterLevel = (name: "CenterLevel", type: "Real32", def: 0.0);
  static const DCFilterCutFreq = (name: "DCFilterCutFreq", type: "Real32", def: 40.0);
  static const DecayTime = (name: "DecayTime", type: "Real32", def: 1.2);
  static const Density = (name: "Density", type: "Real32", def: 80.0);
  static const DensityDelayMax = (name: "DensityDelayMax", type: "Real32", def: 50.0);
  static const DensityDelayMin = (name: "DensityDelayMin", type: "Real32", def: 8.0);
  static const DensityDelayRdmPerc = (name: "DensityDelayRdmPerc", type: "Real32", def: 2.0);
  static const Diffusion = (name: "Diffusion", type: "Real32", def: 100.0);
  static const DiffusionDelayMax = (name: "DiffusionDelayMax", type: "Real32", def: 15.0);
  static const DiffusionDelayRdmPerc = (name: "DiffusionDelayRdmPerc", type: "Real32", def: 5.0);
  static const DiffusionDelayScalePerc = (name: "DiffusionDelayScalePerc", type: "Real32", def: 66.0);
  static const DryLevel = (name: "DryLevel", type: "Real32", def: -96.3);
  static const ERFrontBackDelay = (name: "ERFrontBackDelay", type: "Real32", def: 0.0);
  static const ERLevel = (name: "ERLevel", type: "Real32", def: -20.0);
  static const ERPattern = (name: "ERPattern", type: "int32", def: 23);
  static const EnableEarlyReflections = (name: "EnableEarlyReflections", type: "bool", def: true);
  static const EnableToneControls = (name: "EnableToneControls", type: "bool", def: false);
  static const Filter1Curve = (name: "Filter1Curve", type: "int32", def: 0);
  static const Filter1Freq = (name: "Filter1Freq", type: "Real32", def: 100.0);
  static const Filter1Gain = (name: "Filter1Gain", type: "Real32", def: 0.0);
  static const Filter1InsertPos = (name: "Filter1InsertPos", type: "int32", def: 3);
  static const Filter1Q = (name: "Filter1Q", type: "Real32", def: 1.0);
  static const Filter2Curve = (name: "Filter2Curve", type: "int32", def: 1);
  static const Filter2Freq = (name: "Filter2Freq", type: "Real32", def: 1000.0);
  static const Filter2Gain = (name: "Filter2Gain", type: "Real32", def: 0.0);
  static const Filter2InsertPos = (name: "Filter2InsertPos", type: "int32", def: 3);
  static const Filter2Q = (name: "Filter2Q", type: "Real32", def: 1.0);
  static const Filter3Curve = (name: "Filter3Curve", type: "int32", def: 2);
  static const Filter3Freq = (name: "Filter3Freq", type: "Real32", def: 10000.0);
  static const Filter3Gain = (name: "Filter3Gain", type: "Real32", def: 0.0);
  static const Filter3InsertPos = (name: "Filter3InsertPos", type: "int32", def: 3);
  static const Filter3Q = (name: "Filter3Q", type: "Real32", def: 1.0);
  static const FrontLevel = (name: "FrontLevel", type: "Real32", def: 0.0);
  static const HFDamping = (name: "HFDamping", type: "Real32", def: 2.25);
  static const InputCenterLevel = (name: "InputCenterLevel", type: "Real32", def: 0.0);
  static const InputLFELevel = (name: "InputLFELevel", type: "Real32", def: -96.3);
  static const LFELevel = (name: "LFELevel", type: "Real32", def: -96.3);
  static const PreDelay = (name: "PreDelay", type: "Real32", def: 25.0);
  static const Quality = (name: "Quality", type: "int32", def: 8);
  static const RearLevel = (name: "RearLevel", type: "Real32", def: 0.0);
  static const ReverbLevel = (name: "ReverbLevel", type: "Real32", def: -20.0);
  static const ReverbUnitInputDelay = (name: "ReverbUnitInputDelay", type: "Real32", def: 100.0);
  static const ReverbUnitInputDelayRmdPerc = (name: "ReverbUnitInputDelayRmdPerc", type: "Real32", def: 50.0);
  static const RoomShape = (name: "RoomShape", type: "Real32", def: 100.0);
  static const RoomShapeMax = (name: "RoomShapeMax", type: "Real32", def: 0.8);
  static const RoomShapeMin = (name: "RoomShapeMin", type: "Real32", def: 0.1);
  static const RoomSize = (name: "RoomSize", type: "Real32", def: 0.0);
  static const StereoWidth = (name: "StereoWidth", type: "Real32", def: 180.0);
}
const _roomVerbRtpcProps = {
  0x0a: (name: "DecayTime", type: "Real32"),
  0x0b: (name: "HFDamping", type: "Real32"),
  0x0f: (name: "Diffusion", type: "Real32"),
  0x10: (name: "StereoWidth", type: "Real32"),
  0x17: (name: "Filter1Gain", type: "Real32"),
  0x18: (name: "Filter1Freq", type: "Real32"),
  0x19: (name: "Filter1Q", type: "Real32"),
  0x1c: (name: "Filter2Gain", type: "Real32"),
  0x1d: (name: "Filter2Freq", type: "Real32"),
  0x1e: (name: "Filter2Q", type: "Real32"),
  0x21: (name: "Filter3Gain", type: "Real32"),
  0x22: (name: "Filter3Freq", type: "Real32"),
  0x23: (name: "Filter3Q", type: "Real32"),
  0x32: (name: "FrontLevel", type: "Real32"),
  0x33: (name: "RearLevel", type: "Real32"),
  0x34: (name: "CenterLevel", type: "Real32"),
  0x35: (name: "LFELevel", type: "Real32"),
  0x3c: (name: "DryLevel", type: "Real32"),
  0x3d: (name: "ERLevel", type: "Real32"),
  0x3e: (name: "ReverbLevel", type: "Real32"),
};
List<WwiseProperty> _getRoomVerbProperties(BnkPluginData data) {
  var params = data as BnkRoomVerbFXParams;
  List<(num, ({String name, String type, Object def}))> joinedParams = [
    (params.fCenterLevel, _RoomVerbProperties.CenterLevel),
    (params.fDCFilterCutFreq, _RoomVerbProperties.DCFilterCutFreq),
    (params.fDecayTime, _RoomVerbProperties.DecayTime),
    (params.fDensity, _RoomVerbProperties.Density),
    (params.fDensityDelayMax, _RoomVerbProperties.DensityDelayMax),
    (params.fDensityDelayMin, _RoomVerbProperties.DensityDelayMin),
    (params.fDensityDelayRdmPerc, _RoomVerbProperties.DensityDelayRdmPerc),
    (params.fDiffusion, _RoomVerbProperties.Diffusion),
    (params.fDiffusionDelayMax, _RoomVerbProperties.DiffusionDelayMax),
    (params.fDiffusionDelayRdmPerc, _RoomVerbProperties.DiffusionDelayRdmPerc),
    (params.fDiffusionDelayScalePerc, _RoomVerbProperties.DiffusionDelayScalePerc),
    (params.fDryLevel, _RoomVerbProperties.DryLevel),
    (params.fERFrontBackDelay, _RoomVerbProperties.ERFrontBackDelay),
    (params.fERLevel, _RoomVerbProperties.ERLevel),
    (params.uERPattern, _RoomVerbProperties.ERPattern),
    (params.bEnableEarlyReflections, _RoomVerbProperties.EnableEarlyReflections),
    (params.bEnableToneControls, _RoomVerbProperties.EnableToneControls),
    (params.eFilter1Curve, _RoomVerbProperties.Filter1Curve),
    (params.fFilter1Freq, _RoomVerbProperties.Filter1Freq),
    (params.fFilter1Gain, _RoomVerbProperties.Filter1Gain),
    (params.eFilter1Pos, _RoomVerbProperties.Filter1InsertPos),
    (params.fFilter1Q, _RoomVerbProperties.Filter1Q),
    (params.eFilter2Curve, _RoomVerbProperties.Filter2Curve),
    (params.fFilter2Freq, _RoomVerbProperties.Filter2Freq),
    (params.fFilter2Gain, _RoomVerbProperties.Filter2Gain),
    (params.eFilter2Pos, _RoomVerbProperties.Filter2InsertPos),
    (params.fFilter2Q, _RoomVerbProperties.Filter2Q),
    (params.eFilter3Curve, _RoomVerbProperties.Filter3Curve),
    (params.fFilter3Freq, _RoomVerbProperties.Filter3Freq),
    (params.fFilter3Gain, _RoomVerbProperties.Filter3Gain),
    (params.eFilter3Pos, _RoomVerbProperties.Filter3InsertPos),
    (params.fFilter3Q, _RoomVerbProperties.Filter3Q),
    (params.fFrontLevel, _RoomVerbProperties.FrontLevel),
    (params.fHFDamping, _RoomVerbProperties.HFDamping),
    (params.fInputCenterLevel, _RoomVerbProperties.InputCenterLevel),
    (params.fInputLFELevel, _RoomVerbProperties.InputLFELevel),
    (params.fLFELevel, _RoomVerbProperties.LFELevel),
    (params.fReverbDelay, _RoomVerbProperties.PreDelay),
    (params.uNumReverbUnits, _RoomVerbProperties.Quality),
    (params.fRearLevel, _RoomVerbProperties.RearLevel),
    (params.fReverbLevel, _RoomVerbProperties.ReverbLevel),
    (params.fReverbUnitInputDelay, _RoomVerbProperties.ReverbUnitInputDelay),
    (params.fReverbUnitInputDelayRmdPerc, _RoomVerbProperties.ReverbUnitInputDelayRmdPerc),
    (params.fRoomShape, _RoomVerbProperties.RoomShape),
    (params.fRoomShapeMax, _RoomVerbProperties.RoomShapeMax),
    (params.fRoomShapeMin, _RoomVerbProperties.RoomShapeMin),
    (params.fRoomSize, _RoomVerbProperties.RoomSize),
    (params.fStereoWidth, _RoomVerbProperties.StereoWidth),
  ];
  return joinedParams
    .map((e) {
      var (Object value, (name: name, type: type, def: def)) = e;
      if (type == "bool")
        value = value != 0;
      if (value.runtimeType != def.runtimeType)
        throw Exception("Type mismatch for $name: def is ${def.runtimeType}, value is ${value.runtimeType}");
      if (value == def)
        return null;
      return WwiseProperty(name, type, value: value.toString());
    })
    .whereType<WwiseProperty>()
    .toList();
}

Future<void> saveEffectsIntoWu(WwiseProjectGenerator project) async {
  for (var effectC in project.hircChunksByType<BnkFxCustom>()) {
    var effect = effectC.value;
    if (_ignorePluginIds.contains(effect.fxId))
      continue;
    var config = _pluginConfigs[effect.fxId];
    if (config == null) {
      project.log(WwiseLogSeverity.warning, "Unknown effect id ${effect.fxId}");
      continue;
    }
    var effectElement = WwiseEffect(wuId: project.effectsWu.id, project: project, effect: effect, config: config);
    if (effect.isShareSet)
      project.effectsWu.addWuChild(effectElement, effect.uid, effectC.names);
  }

  await project.effectsWu.save();
}
