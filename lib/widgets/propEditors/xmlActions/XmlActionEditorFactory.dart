
import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../utils/utils.dart';
import 'DelayAction.dart';
import 'XmlActionEditor.dart';

final Map<int, Widget Function(XmlActionProp, bool)> actionsFactories = {
  crc32("DelayAction"): (action, showDetails) => DelayActionEditor(action: action, showDetails: showDetails,),
};

Widget makeXmlActionEditor({ required XmlActionProp action, required bool showDetails}) {
  var factory = actionsFactories[action.code.value];
  if (factory != null)
    return factory(action, showDetails);
  return XmlActionEditor(action: action, showDetails: showDetails);
}
