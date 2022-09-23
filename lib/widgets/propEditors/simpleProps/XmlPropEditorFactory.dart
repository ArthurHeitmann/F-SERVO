

import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../customXmlProps/transformsEditor.dart';
import 'XmlPropEditor.dart';

Widget makeXmlPropEditor(XmlProp prop) {
  return XmlPropEditor(prop: prop);
}

List<Widget> makeXmlMultiPropEditor(XmlProp parent, [bool Function(XmlProp)? filter]) {
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
      widgets.add(makeXmlPropEditor(parent[i]));
    }
  }

  return widgets;
}
