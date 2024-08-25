
import 'package:xml/xml.dart';

import '../../fileTypeUtils/audio/bnkIO.dart';
import '../utils.dart';
import 'elements/wwiseCurve.dart';
import 'wwiseElement.dart';
import 'wwiseProjectGenerator.dart';


class WwisePropertyList {
  final Map<String, WwiseProperty> _properties = {};

  WwisePropertyList(List<WwiseProperty> properties) {
    for (var prop in properties) {
      add(prop);
    }
  }

  void add(WwiseProperty prop) {
    if (!_properties.containsKey(prop.name)) {
      _properties[prop.name] = prop;
      return;
    }
    var existing = _properties[prop.name]!;
    if (prop.type != existing.type) {
      throw Exception("Property with name ${prop.name} already exists with type ${existing.type}");
    }
    _properties[prop.name] = WwiseProperty(
      prop.name,
      prop.type,
      value: prop.value ?? existing.value,
      values: prop.values.isNotEmpty ? prop.values : existing.values,
      modifierRange: prop.modifierRange ?? existing.modifierRange,
      project: prop.project ?? existing.project,
      rtpcs: [
        ...existing.rtpcs,
        for (var rtpc in prop.rtpcs)
          if (!existing.rtpcs.any((e) => e.rtpcCurveID == rtpc.rtpcCurveID))
            rtpc
      ],
    );
  }

  XmlElement toXml() {
    var properties = _properties.entries.toList();
    properties.sort((a, b) => a.key.compareTo(b.key));
    return makeXmlElement(
      name: "PropertyList",
      children: properties.map((e) => e.value.toXml()).toList(),
    );
  }

  bool get isEmpty => _properties.isEmpty;
  bool get isNotEmpty => _properties.isNotEmpty;
}


class WwiseProperty {
	final String name;
	final String type;
  final String? value;
  final List<String> values;
  final ({String min, String max})? modifierRange;
  final WwiseProjectGenerator? project;
  final List<BnkRtpc> rtpcs;

  WwiseProperty(
    this.name,
    this.type,
    {
      this.value,
      List<String>? values,
      this.modifierRange,
      this.project,
      List<BnkRtpc>? rtpcs,
    }
  ) :
    values = values ?? [],
    rtpcs = rtpcs ?? []
  {
    if ((modifierRange != null || this.rtpcs.isNotEmpty) && project == null) {
      throw Exception("Modifier range requires a project");
    }
  }

  XmlElement toXml() {
    return makeXmlElement(
      name: "Property",
      attributes: {
        "Name": name,
        "Type": type,
        if (value != null)
          "Value": value!,
      },
      children: [
        if (values.isNotEmpty)
          makeXmlElement(
            name: "ValueList",
            children: values.map((e) => makeXmlElement(name: "Value", text: e)).toList(),
          ),
        if (modifierRange != null)
          makeXmlElement(name: "ModifierList", children: [
            makeXmlElement(name: "ModifierInfo", children: [
              makeXmlElement(name: "Modifier", attributes: {
                "Name": "",
                "ID": project!.idGen.uuid(),
              }, children: [
                WwisePropertyList([
                  WwiseProperty("Min", "Real64", value: modifierRange!.min),
                  WwiseProperty("Max", "Real64", value: modifierRange!.max),
                ]).toXml(),
              ]),
            ]),
          ]),
        if (rtpcs.isNotEmpty)
          makeXmlElement(name: "RTPCList", children: rtpcs.map((rtpc) {
            var parameter = project!.gameParameters[rtpc.rtpcId]!;
            return WwiseElement(
              wuId: "",
              project: project!,
              tagName: "RTPC",
              name: "",
              shortId: rtpc.rtpcCurveID,
              additionalChildren: [
                makeXmlElement(name: "GameParameterRef", attributes: {"Name": parameter.name, "ID": parameter.id.toString()}),
                WwiseCurve(
                  wuId: "",
                  project: project!,
                  name: "",
                  isVolume: name.contains("Volume"),
                  scalingType: rtpc.eScaling,
                  points: rtpc.rtpcGraphPoint,
                ).toXml(),
              ]
            ).toXml();
          }).toList())
      ]
    );
  }
}
