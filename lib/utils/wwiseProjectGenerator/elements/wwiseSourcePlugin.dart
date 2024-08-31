
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';

typedef _PluginConfig = ({List<WwiseProperty> Function(BnkPluginData data) handler, String name, String pluginId});
const Map<int, _PluginConfig> _pluginConfigs = {
  0x00640002: (name: "Sine", pluginId: "100", handler: _getSineProperties),
  0x00650002: (name: "Silence", pluginId: "101", handler: _getSilenceProperties),
};

class WwiseSourcePlugin extends WwiseElement {
  WwiseSourcePlugin._({required super.wuId, required super.project, required super.shortId, required _PluginConfig config, required BnkPluginData pluginData, required String language}) : super(
    tagName: "SourcePlugin",
    name: config.name,
    shortIdType: ShortIdType.object,
    properties: config.handler(pluginData),
    additionalAttributes: {
      "PluginName": config.name,
      "CompanyID": "0",
      "PluginID": config.pluginId,
    },
    additionalChildren: [makeXmlElement(name: "Language", text: language)],
  );

  factory WwiseSourcePlugin({required String wuId, required WwiseProjectGenerator project, required int fxId, required String language}) {
    var chunk = project.hircChunkById<BnkFxCustom>(fxId)!;
    var config = _pluginConfigs[chunk.fxId]!;
    return WwiseSourcePlugin._(
      wuId: wuId,
      project: project,
      shortId: fxId,
      config: config,
      pluginData: chunk.pluginData,
      language: language,
    );
  }

  static bool isSourcePlugin(WwiseProjectGenerator project, int srcId) {
    var chunk = project.hircChunkById<BnkFxCustom>(srcId);
    return chunk != null && _pluginConfigs.containsKey(chunk.fxId);
  }
}

List<WwiseProperty> _getSineProperties(BnkPluginData data) {
  var sine = data as BnkFxSineParams;
  return [
    if (sine.fDuration != 1.0)
      WwiseProperty("SineDuration", "Real32", value: sine.fDuration.toString()),
    if (sine.fFrequency != 440.0)
      WwiseProperty("SineFrequency", "Real32", value: sine.fFrequency.toString()),
    if (sine.fGain != -12.0)
      WwiseProperty("SineGain", "Real32", value: sine.fGain.toString()),
    if (sine.uChannelMask != 4)
      WwiseProperty("ChannelMask", "int32", values: [sine.uChannelMask.toString()]),
  ];
}

List<WwiseProperty> _getSilenceProperties(BnkPluginData data) {
  var silence = data as BnkFxSilenceParams;
  return [
    if (silence.fDuration != 1.0)
      WwiseProperty("Length", "Real32", value: silence.fDuration.toString()),
    if (silence.fRandomizedLengthMinus != 4)
      WwiseProperty("LengthMin", "Real32", value: silence.fRandomizedLengthMinus.toString()),
    if (silence.fRandomizedLengthPlus != 4)
      WwiseProperty("LengthMax", "Real32", value: silence.fRandomizedLengthPlus.toString()),
  ];
}
