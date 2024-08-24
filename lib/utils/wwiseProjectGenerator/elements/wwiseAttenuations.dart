
import 'dart:math';

import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import '../wwiseUtils.dart';
import 'wwiseCurve.dart';

const _attenuationCurveConfigs = [
  (name: "VolumeDry", isVolume: true, defaultStartY: 0.0, defaultEndY: -1.0, defaultScalingType: 2),
  (name: "VolumeWet", isVolume: true, defaultStartY: 0.0, defaultEndY: -1.0, defaultScalingType: 2),
  (name: "LowPassFilter", isVolume: false, defaultStartY: 0.0, defaultEndY: 100.0, defaultScalingType: null),
  (name: "Spread", isVolume: false, defaultStartY: 100.0, defaultEndY: 0.0, defaultScalingType: null),
];

const _rtpcPropConfig = {
  0x0D: (name: "ConeAttenuation", type: "Real64"),
  0x0E: (name: "ConeLowPassFilterValue", type: "int32"),
};

class WwiseAttenuation extends WwiseElement {
  final BnkAttenuation attenuation;
  late final double maxX;

  WwiseAttenuation({required super.wuId, required super.project, required super.name, required this.attenuation}) : super(
    tagName: "Attenuation",
    shortId: attenuation.uid,
    properties: [
      if (attenuation.bIsConeEnabled != 0) ...[
        WwiseProperty("ConeUse", "bool", values: ["True"]),
        if (attenuation.coneParams!.fInsideDegrees != 90)
          WwiseProperty("ConeInnerAngle", "int32", value: attenuation.coneParams!.fInsideDegrees.round().toString()),
        if (attenuation.coneParams!.fOUtsideDegrees != 245)
          WwiseProperty("ConeOuterAngle", "int32", value: attenuation.coneParams!.fOUtsideDegrees.round().toString()),
        if (attenuation.coneParams!.fOutsideVolume != -6)
          WwiseProperty("ConeAttenuation", "Real64", values: [attenuation.coneParams!.fOutsideVolume.toString()]),
        if (attenuation.coneParams!.fLoPass != 0)
          WwiseProperty("ConeLowPassFilterValue", "int32", values: [attenuation.coneParams!.fLoPass.round().toString()]),
      ],
    ]
  ) {
    maxX = attenuation.curves
        .map((curve) => curve.rtpcGraphPoint)
        .expand((points) => points)
        .map((point) => point.x)
        .reduce(max);
    if (maxX != 100)
      properties.add(WwiseProperty("RadiusMax", "Real64", value: maxX.toString()));
    
    for (var rtpc in attenuation.rtpcs) {
      var config = _rtpcPropConfig[rtpc.paramID];
      if (config == null) {
        project.log(WwiseLogSeverity.warning, "Unknown rtpc curve id ${rtpc.paramID}");
        continue;
      }
      properties.add(WwiseProperty(config.name, config.type, project: project, rtpcs: [rtpc]));
    }

    additionalChildren.add(makeXmlElement(name: "CurveUsageInfoList", children: [
      for (int i = 0; i < 4; i++)
        _makeCurveUsage(i, attenuation.curveToUse[i])
    ]));
  }

  XmlElement _makeCurveUsage(int i, int referencedCurve) {
    var config = _attenuationCurveConfigs[i];
    BnkConversionTable? curve;
    String curveToUse;
    if (i == 0) {
      curve = attenuation.curves[referencedCurve];
      curveToUse = "Custom";
    } else if (referencedCurve == -1) {
      curveToUse = "None";
    } else if (referencedCurve != 0) {
      curve = attenuation.curves[referencedCurve];
      curveToUse = "Custom";
    } else {
      curveToUse = "Use${_attenuationCurveConfigs[0].name}";
    }
    var points = curve?.rtpcGraphPoint;
    points ??= [
      BnkRtpcGraphPoint(0, config.defaultStartY, 4),
      BnkRtpcGraphPoint(maxX, config.defaultEndY, 4),
    ];
    
    return makeXmlElement(name: "${config.name}Usage", children: [
      makeXmlElement(
        name: "CurveUsageInfo",
        attributes: {
          "Platform": "Linked",
          "CurveToUse": curveToUse,
        },
        children: [WwiseCurve(
          wuId: wuId,
          project: project,
          name: config.name,
          isVolume: config.isVolume,
          scalingType: curve?.eScaling ?? config.defaultScalingType,
          points: points
        ).toXml()],
      ),
    ]);
  }
}

Future<void> saveAttenuationsIntoWu(WwiseProjectGenerator project) async {
  for (var attenuation in project.hircChunksByType<BnkAttenuation>()) {
    var attenuationElement = WwiseAttenuation(
      wuId: project.attenuationsWu.id,
      project: project,
      name: wwiseIdToStr(attenuation.uid, fallbackPrefix: "Attenuation"),
      attenuation: attenuation
    );
    project.attenuationsWu.children.add(attenuationElement);
  }

  await project.attenuationsWu.save();
}
