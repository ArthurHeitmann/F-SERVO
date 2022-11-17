
import 'package:flutter/material.dart';

import '../../../stateManagement/xmlProps/xmlActionProp.dart';
import '../../../utils/utils.dart';
import 'DelayAction.dart';
import 'XmlActionEditor.dart';
import 'XmlActionWithAreaEditor.dart';
import 'XmlBezierActionEditor.dart';
import 'XmlEnemyGeneratorActionEditor.dart';
import 'XmlEntityActionEditor.dart';

final Map<int, Widget Function(XmlActionProp, bool)> actionsFactories = {
  crc32("DelayAction"): (action, showDetails) => DelayActionEditor(action: action, showDetails: showDetails,),
  crc32("EntityLayoutAction"): (action, showDetails) => XmlEntityActionEditor(action: action, showDetails: showDetails,),
  crc32("EntityLayoutArea"): (action, showDetails) => XmlEntityActionEditor(action: action, showDetails: showDetails,),
  crc32("EnemySetAction"): (action, showDetails) => XmlEntityActionEditor(action: action, showDetails: showDetails,),
  crc32("EnemySetArea"): (action, showDetails) => XmlEntityActionEditor(action: action, showDetails: showDetails,),
  crc32("SQ090_Layout"): (action, showDetails) => XmlEntityActionEditor(action: action, showDetails: showDetails,),
  crc32("BezierCurveAction"): (action, showDetails) => XmlBezierActionEditor(action: action, showDetails: showDetails,),
  crc32("ShootingEnemyCurveAction"): (action, showDetails) => XmlBezierActionEditor(action: action, showDetails: showDetails,),
  crc32("AirBezierAction"): (action, showDetails) => XmlBezierActionEditor(action: action, showDetails: showDetails,),
  crc32("EnemyGenerator"): (action, showDetails) => XmlEnemyGeneratorActionEditor(action: action, showDetails: showDetails,),
};

Widget makeXmlActionEditor({ required XmlActionProp action, required bool showDetails}) {
  var factory = actionsFactories[action.code.value];
  if (factory != null)
    return factory(action, showDetails);
  if (action.skip(4).any(isAreaProp))
    return XmlActionWithAreaEditor(action: action, showDetails: showDetails);
  return XmlActionEditor(action: action, showDetails: showDetails);
}
