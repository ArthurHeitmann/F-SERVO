
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../utils.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'hierarchyBaseElements.dart';
import 'wwiseAudioFileSource.dart';
import 'wwiseCurve.dart';

const _fadeInConfig = (type: 2, name: "FadeIn", defaultShape: 1);
const _fadeOutConfig = (type: 3, name: "FadeOut", defaultShape: 8);

const _propertyCurveConfigs = {
  0x0: (name: "Volume", factor: 10.0),
  0x1: (name: "Lowpass", factor: 1.0),
};

const _bnkFadeInterpolationToWwiseShape = {
  0x0: (id: 0, name: "Log3"),	// Logarithmic (Base 3)
  0x1: (id: 1, name: "Log2"),	// Sine
  0x2: (id: 2, name: "Log1"),	// Logarithmic (Base 1.41)
  0x3: (id: 3, name: "InvertedSCurve"),	// Inverted S-Curve
  0x4: (id: 4, name: "Linear"),	// Linear
  0x5: (id: 6, name: "SCurve"),	// S-Curve
  0x6: (id: 7, name: "Exp1"),	// Exponential (Base 1.41)
  0x7: (id: 8, name: "Exp2"),	// Reciprocal Sine
  0x8: (id: 9, name: "Exp3"),	// Exponential (Base 3)
  0x9: (id: -1, name: "Constant"),	// Constant
};

class WwiseMusicTrack extends WwiseHierarchyElement<BnkMusicTrack> {
  WwiseMusicTrack({required super.wuId, required super.project, required super.chunk}) : super(
    tagName: "MusicTrack",
    name: makeElementName(project, id: chunk.uid, parentId: chunk.baseParams.directParentID, name: wemIdsToNames[chunk.sources.first.sourceID] ?? wemIdsToNames[chunk.sources.first.fileID], category: "Music Track"),
    shortId: chunk.uid,
    properties: [
      if (project.options.streaming && (chunk.sources.firstOrNull?.streamType ?? 0) >= 1)
        WwiseProperty("IsStreamingEnabled", "bool", values: ["True"]),
      if (project.options.streaming && project.options.streamingPrefetch && (chunk.sources.firstOrNull?.streamType ?? 0) == 2)
        WwiseProperty("IsZeroLantency", "bool", values: ["True"]),
      if (chunk.iLookAheadTime != 100)
        WwiseProperty("LookAheadTime", "int16", value: chunk.iLookAheadTime.toString()),
      if (chunk.eRSType != 0)
        WwiseProperty("MusicTrackType", "int16", value: chunk.eRSType.toString()),
    ],
    children: chunk.sources.map((src) {
      var soundFile = project.soundFiles[src.sourceID];
      if (soundFile == null)
        return null;
      return WwiseAudioFileSource(wuId: wuId, project: project, audio: soundFile);
    })
    .whereType<WwiseAudioFileSource>()
    .toList(),
  );
  
  @override
  void oneTimeInit() {
    super.oneTimeInit();
    additionalChildren.add(makeXmlElement(name: "SequenceList", children: [makeXmlElement(
      name: "MusicTrackSequence",
      attributes: {"Name": "", "ID": project.idGen.uuid()},
      children: [makeXmlElement(
        name: "ClipList",
        children: chunk.playlists.indexed
          .map((iPl) {
            var (i, pl) = iPl;
            var audioSrc = children
              .whereType<WwiseAudioFileSource>()
              .where((src) => pl.sourceID == src.audio.id || pl.sourceID == src.audio.prefetchId)
              .firstOrNull;
            if (audioSrc == null)
              return null;
            var graphCurves = chunk.clipAutomations
              .where((ca) => ca.uClipIndex == i)
              .where((ca) => ca.eAutoType != _fadeInConfig.type && ca.eAutoType != _fadeOutConfig.type)
              .toList();
            return makeXmlElement(
              name: "MusicClip",
              attributes: {"Name": wwiseIdToStr(pl.sourceID, fallbackPrefix: "Playlist"), "ID": project.idGen.uuid()},
              children: [
                WwisePropertyList([
                    WwiseProperty("PlayAt", "Real64", value: pl.fPlayAt.toString()),
                    WwiseProperty("BeginTrimOffset", "Real64", value: pl.fBeginTrimOffset.toString()),
                    WwiseProperty("EndTrimOffset", "Real64", value: (pl.fSrcDuration + pl.fEndTrimOffset).toString()),
                    ..._makeFadeProperties(i, _fadeInConfig),
                    ..._makeFadeProperties(i, _fadeOutConfig),
                ]).toXml(),
                makeXmlElement(name: "AudioSourceRef", attributes: {"Name": audioSrc.name, "ID": audioSrc.id}),
                if (graphCurves.isNotEmpty)
                  makeXmlElement(name: "PropertyCurveList", children: [
                    for (var curve in graphCurves)
                      _makePropertyCurve(curve),
                  ]),
              ],
            );
          })
          .whereType<XmlElement>()
          .toList(),
      )]
    )]));
  }

  List<WwiseProperty> _makeFadeProperties(int playlistIndex, ({int type, String name, int defaultShape}) config) {
    var (type: fadeType, name: fadeName, defaultShape: defaultShape) = config;
    var clipAutomation = chunk.clipAutomations
      .where((ca) => ca.eAutoType == fadeType)
      .where((ca) => ca.uClipIndex == playlistIndex)
      .firstOrNull;
    if (clipAutomation == null) {
      return [
        WwiseProperty("${fadeName}Mode", "int16", value: "0"),
      ];
    }
    if (clipAutomation.uNumPoints != 2 && clipAutomation.uNumPoints != 3) {
      throw Exception("Unexpected number of points (${clipAutomation.uNumPoints}) in clip automation");
    }
    var first = clipAutomation.uNumPoints == 2 ? clipAutomation.rtpcGraphPoint[0] : clipAutomation.rtpcGraphPoint[1];
    var last = clipAutomation.rtpcGraphPoint.last;
    var duration = last.x - first.x;
    var shape = _bnkFadeInterpolationToWwiseShape[first.interpolation]!.id;
    return [
      WwiseProperty("${fadeName}Mode", "int16", value: "1"),
      if (shape != defaultShape)
        WwiseProperty("${fadeName}Shape", "int16", value: shape.toString()),
      WwiseProperty("${fadeName}Duration", "Real64", value: duration.toString()),
    ];
  }

  XmlElement _makePropertyCurve(BnkClipAutomation curve) {
    var config = _propertyCurveConfigs[curve.eAutoType];
    if (config == null) {
      throw Exception("Unknown property curve type ${curve.eAutoType}");
    }
    return makeXmlElement(
      name: "PropertyCurve",
      attributes: {"PropertyName": config.name},
      children: [
        WwiseCurve(
          wuId: wuId,
          project: project,
          name: "",
          isVolume: curve.eAutoType == 0,
          scalingType: null,
          fallbackFlag: "1",
          scalingFactor: config.factor,
          points: curve.rtpcGraphPoint,
        ).toXml(),
      ],
    );
  }
}
