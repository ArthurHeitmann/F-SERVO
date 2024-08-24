
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';
import '../wwiseUtils.dart';
import 'wwiseAction.dart';

Future<void> saveEventsHierarchy(WwiseProjectGenerator project) async {
  var actionsMap = {
    for (var action in project.hircChunksByType<BnkAction>())
      action.uid: action
  };

  for (var event in project.hircChunksByType<BnkEvent>()) {
    project.eventsWu.addChild(WwiseElement(
      wuId: project.eventsWu.id,
      project: project,
      tagName: "Event",
      name: wwiseIdToStr(event.uid),
      shortIdHint: event.uid,
      children: [
        for (var actionId in event.ids)
          if (project.options.actions && actionsMap.containsKey(actionId))
            WwiseAction(wuId: project.eventsWu.id, project: project, action: actionsMap[actionId]!)
      ]
    ), event.uid);
  }
  for (var child in project.eventsWu.children) {
    child.oneTimeInit();
  }

  await project.eventsWu.save();
}