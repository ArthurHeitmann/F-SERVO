
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseProperty.dart';
import 'wwiseAttenuations.dart';

XmlElement? makeWwisePositioningInfo(WwiseProjectGenerator project, WwiseElement parent, BnkPositioningParams positioning, List<WwiseProperty> pannerProps) {
  if (positioning.bIsPannerEnabled != 1 && positioning.cbIs3DPositioningAvailable != 1 && (positioning.attenuationID ?? 0) == 0) {
    return null;
  }

  List<XmlElement> children = [];

  if ((positioning.attenuationID ?? 0) != 0) {
    var attenuation = project.lookupElement(idFnv: positioning.attenuationID!) as WwiseAttenuation?;
    if (attenuation == null) {
      project.log(WwiseLogSeverity.warning, "Attenuation with ID ${positioning.attenuationID} not found");
    } else {
      children.add(makeXmlElement(name: "AttenuationInfo", children: [
        makeXmlElement(
          name: "AttenuationRef",
          attributes: {
            "Name": attenuation.name,
            "ID": attenuation.id,
            "Platform": "Linked",
          }
        ),
      ]));
    }
  }

  if (positioning.bIsPannerEnabled == 1) {
    children.add(makeXmlElement(
      name: "Panner",
      attributes: {"Name": "", "ID": project.idGen.uuid()},
      children: [
        if (pannerProps.isNotEmpty)
          WwisePropertyList(pannerProps).toXml(),
      ]
    ));
  }

  if (positioning.cbIs3DPositioningAvailable == 1 && positioning.eType_ == 2) {
    List<WwiseElement> paths = [];

    for (int i = 0; i < positioning.ulNumPlayListItem!; i++) {
      var vertexInfo = positioning.pPlayListItems![i];
      var params = positioning.params![i];
      var vertices = positioning.pVertices!
        .skip(vertexInfo.verticesOffset)
        .take(vertexInfo.verticesCount)
        .toList();
      var duration = vertices.fold(0, (prev, vertex) => prev + vertex.duration);

      List<XmlElement> points = [];
      int time = 0;
      for (var vertex in vertices) {
        points.add(makeXmlElement(
          name: "Point",
          children: [
            makeXmlElement(name: "XPos", text: vertex.x.toString()),
            makeXmlElement(name: "YPos", text: vertex.z.toString()),
            makeXmlElement(name: "Flags", text: vertex == vertices.first ? "12" : "0"),
            makeXmlElement(name: "Time", text: time.toString()),
          ]
        ));
        time += vertex.duration;
      }

      paths.add(WwiseElement(
        wuId: parent.wuId,
        project: project,
        tagName: "Path2D",
        name: "${parent.name}_Path $i",
        properties: [
          if (params.xRange != 0)
            WwiseProperty("RandomX", "Real64", value: params.xRange.toString()),
          if (params.yRange != 0)
            WwiseProperty("RandomY", "Real64", value: params.yRange.toString()),
          if (duration != 5000)
            WwiseProperty("Duration", "int32", value: duration.toString()),
        ],
        additionalChildren: [makeXmlElement(
          name: "PointList",
          children: points,
        )],
      ));
    }

    var isRandom = positioning.ePathMode! & 1 != 0;
    var isContinuous = positioning.ePathMode! & 2 != 0;
    var pickNewPath = positioning.ePathMode! & 4 != 0;
    children.add(WwiseElement(
      wuId: parent.wuId,
      project: project,
      tagName: "Position",
      name: "",
      properties: [
        if (isRandom)
          WwiseProperty("PlayMechanismRandomOrSequence", "int16", value: "1"),
        if (isContinuous)
          WwiseProperty("PlayMechanismStepOrContinuous", "int16", value: "0"),
        if (pickNewPath)
          WwiseProperty("NewPathForEachSound", "bool", value: "True"),
        if (positioning.bIsLooping! == 0)
          WwiseProperty("PlayMechanismLoop", "bool", value: "False"),
      ],
      children: paths,
    ).toXml());
  }

  return makeXmlElement(
    name: "PositioningInfo",
    children: children,
  );
}
