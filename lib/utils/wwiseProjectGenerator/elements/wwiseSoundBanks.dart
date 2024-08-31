
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseElementBase.dart';
import '../wwiseProjectGenerator.dart';
import 'wwiseWorkUnit.dart';

Future<void> makeWwiseSoundBank(WwiseProjectGenerator project) async {
  project.soundBanksWu.defaultChildren.clear();
  var wuChildren = [project.amhWu, project.imhWu, project.eventsWu];
  void markBnkUsage(WwiseElementBase obj) {
    for (var child in obj.children)
      markBnkUsage(child);
    var childBnkNames = obj.children
      .map((e) => e.parentBnks)
      .expand((e) => e)
      .whereType<String>()
      .toSet();
    if (childBnkNames.length == 1)
      obj.parentBnks.addAll(childBnkNames);
  }
  for (var obj in wuChildren)
    markBnkUsage(obj);
  
  for (var bnkName in project.bnkNames) {
    List<WwiseElementBase> topLevelObjects = [];
    void findTopLevelObjects(WwiseElementBase obj) {
      if (obj.parentBnks.contains(bnkName)) {
        topLevelObjects.add(obj);
        return;
      }
      for (var child in obj.children)
        findTopLevelObjects(child);
    }
    for (var obj in wuChildren)
      findTopLevelObjects(obj);


    project.soundBanksWu.addChild(WwiseElement(
      wuId: project.soundBanksWu.id,
      project: project,
      tagName: "SoundBank",
      name: bnkName,
      additionalChildren: [
        makeXmlElement(name: "ObjectInclusionList", children: [
          for (var element in topLevelObjects)
            makeXmlElement(name: "ObjectRef", attributes: {
              "Name": element.name,
              "ID": element.id,
              "WorkUnitID": element is WwiseElement ? element.wuId : (element as WwiseWorkUnit).workUnitId,
              "Filter": "7",
              "Origin": "Manual",
            }),
        ]),
        makeXmlElement(name: "ObjectExclusionList"),
        makeXmlElement(name: "GameSyncExclusionList"),
      ]
    ));
  }
  await project.soundBanksWu.save();
}
