
import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../utils.dart';
import 'DelayAction.dart';
import 'XmlActionEditor.dart';

final Map<int, Widget Function(XmlActionProp)> actionsFactories = {
  crc32("DelayAction"): (action) => DelayActionEditor(action: action),
};

Widget makeXmlActionEditor({ required XmlActionProp action }) {
  var factory = actionsFactories[action.code.value];
  if (factory != null)
    return factory(action);
  return XmlActionEditor(action: action);
}
