

import 'package:flutter/material.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/xmlProps/xmlProp.dart';
import '../../../utils.dart';
import '../customXmlProps/areaEditor.dart';
import '../customXmlProps/commandEditor.dart';
import '../customXmlProps/conditionEditor.dart';
import '../customXmlProps/entityEditor.dart';
import '../customXmlProps/layoutsEditor.dart';
import '../customXmlProps/paramEditor.dart';
import '../customXmlProps/puidReferenceEditor.dart';
import '../customXmlProps/transformsEditor.dart';
import 'XmlPropEditor.dart';
import 'propTextField.dart';

Widget makeXmlPropEditor<T extends PropTextField>(XmlProp prop, bool showDetails) {
  // area editor
  if (prop.isNotEmpty && prop[0].tagName == "code" && prop[0].value is HexProp && _areaTypes.contains((prop[0].value as HexProp).value)) {
    return AreaEditor(prop: prop, showDetails: showDetails,);
  }
  // entity editor
  if (prop.isNotEmpty && prop.get("objId") != null) {
    return EntityEditor(prop: prop, showDetails: showDetails,);
  }
  // entity layouts
  if (prop.tagName == "layouts" && prop.get("normal")?.get("layouts") != null) {
    return LayoutsEditor(prop: prop, showDetails: showDetails,);
  }
  // param
  if (prop.length == 3 && prop[0].tagName == "name" && prop[1].tagName == "code" && prop[2].tagName == "body") {
    return ParamsEditor(prop: prop, showDetails: showDetails);
  }
  // condition
  if (prop.get("puid") != null && prop.get("condition") != null) {
    return ConditionEditor(prop: prop, showDetails: showDetails);
  }
  // fallback
  return XmlPropEditor<T>(prop: prop, showDetails: showDetails,);
}

List<Widget> makeXmlMultiPropEditor<T extends PropTextField>(XmlProp parent, bool showDetails, [bool Function(XmlProp)? filter]) {
  List<Widget> widgets = [];

  // <id><id> ... </id></id> shortcut
  if (parent.length == 1 && parent[0].length == 1 && parent[0].tagName == "id" && parent[0][0].tagName == "id") {
    return makeXmlMultiPropEditor<T>(parent[0][0], showDetails, filter);
  }

  for (var i = 0; i < parent.length; i++) {
    var child = parent[i];
    if (filter != null && !filter(child)) {
      continue;
    }
    if (_skipPropNames.contains(child.tagName)) {
      continue;
    }
    // transformable with position, rotation (optional), scale (optional)
    if (child.tagName == "location") {
      widgets.add(TransformsEditor(parent: parent));
      if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
        i++;
    }
    else if (child.tagName == "position") {
      widgets.add(TransformsEditor(parent: parent));
      if (i + 1 < parent.length && parent[i + 1].tagName == "rotation") {
        i++;
        if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
          i++;
      }
      else if (i + 1 < parent.length && parent[i + 1].tagName == "scale")
        i++;
    }
    // puid references
    else if (child.tagName == "code" && _puidRefCodes.contains((child.value as HexProp).value)) {
      widgets.add(PuidReferenceEditor(prop: parent, showDetails: showDetails,));
      if (i + 1 < parent.length && _puidRefIdTags.contains(parent[i + 1].tagName))
        i++;
    }
    // command
    else if (child.tagName == "puid" && i + 1 < parent.length && (parent[i + 1].tagName == "command" || parent[i + 1].tagName == "hit")) {
      widgets.add(CommandEditor(prop: parent, showDetails: showDetails));
      i++;
      if (i + 1 < parent.length && parent[i + 1].tagName == "hitout")
        i++;
      if (i + 1 < parent.length && parent[i + 1].tagName == "args")
        i++;
    }
    // fallback
    else {
      widgets.add(makeXmlPropEditor<T>(child, showDetails));
    }
  }

  return widgets;
}

const _skipPropNames = [
  "bForwardState",
  "bDisable"
];

final _areaTypes = {
  crc32("app::area::BoxArea"),
  crc32("app::area::CylinderArea"),
  crc32("app::area::SphereArea"),
};

final _puidRefCodes = {
  crc32("LayoutObj"),
  crc32("app::EntityLayout"),
  crc32("hap::Action"),
  crc32("hap::GroupImpl"),
  crc32("hap::Hap"),
  crc32("hap::SceneEntities"),
  crc32("hap::StateObject"),
};

const _puidRefIdTags = {
  "id",
  "value",
};
