

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../customXmlProps/areaEditor.dart';
import '../customXmlProps/transformsEditor.dart';
import 'XmlPropEditor.dart';

Widget makeXmlPropEditor(XmlProp prop, bool showDetails) {
  // area editor
  if (prop.isNotEmpty && prop[0].tagName == "code" && prop[0].value is HexProp && _areaTypes.contains((prop[0].value as HexProp).value)) {
    return AreaEditor(prop: prop, showDetails: showDetails,);
  }
  // fallback
  return XmlPropEditor(prop: prop, showDetails: showDetails,);
}

List<Widget> makeXmlMultiPropEditor(XmlProp parent, bool showDetails, [bool Function(XmlProp)? filter]) {
  List<Widget> widgets = [];

  for (var i = 0; i < parent.length; i++) {
    if (filter != null && !filter(parent[i])) {
      continue;
    }
    // transformable with position, rotation (optional), scale (optional)
    if (parent[i].tagName == "location") {
      widgets.add(TransformsEditor(parent: parent));
      if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
        i++;
    }
    else if (parent[i].tagName == "position") {
      widgets.add(TransformsEditor(parent: parent));
      if (i + 1 < parent.length && parent[i + 1].tagName == "rotation") {
        i++;
        if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
          i++;
      }
      else if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
        i++;
    }
    // fallback
    else {
      widgets.add(makeXmlPropEditor(parent[i], showDetails));
    }
  }

  return widgets;
}

final _areaTypes = [
  crc32("app::area::BoxArea"),
  crc32("app::area::CylinderArea"),
  crc32("app::area::SphereArea"),
];
