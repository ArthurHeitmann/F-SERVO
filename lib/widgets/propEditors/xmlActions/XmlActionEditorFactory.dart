
import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../utils.dart';
import 'DelayAction.dart';
import 'XmlActionEditor.dart';

final Map<int, Widget Function(Key?, XmlActionProp)> actionsFactories = {
  crc32("DelayAction"): (key, action) => DelayActionEditor(key: key, action: action),
};

Widget makeXmlActionEditor({ Key? key, required XmlActionProp action }) {
  var factory = actionsFactories[action.code.value];
  if (factory != null)
    return factory(key, action);
  return XmlActionEditor(key: key, action: action);
}
