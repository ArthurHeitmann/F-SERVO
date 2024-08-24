
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProjectGenerator.dart';

Future<void> makeWwiseSoundBank(WwiseProjectGenerator project) async {
  project.soundBanksWu.defaultChildren.clear();
  project.soundBanksWu.children.add(
    WwiseElement(
      wuId: project.soundBanksWu.id,
      project: project,
      tagName: "SoundBank",
      name: project.projectName,
      additionalChildren: [
        makeXmlElement(name: "ObjectInclusionList", children: [
          makeXmlElement(name: "ObjectRef", attributes: {
            "Name": project.amhWu.name,
            "ID": project.amhWu.id,
            "WorkUnitID": project.amhWu.workUnitId,
            "Filter": "7",
            "Origin": "Manual",
          }),
          makeXmlElement(name: "ObjectRef", attributes: {
            "Name": project.imhWu.name,
            "ID": project.imhWu.id,
            "WorkUnitID": project.imhWu.workUnitId,
            "Filter": "7",
            "Origin": "Manual",
          }),
          makeXmlElement(name: "ObjectRef", attributes: {
            "Name": project.eventsWu.name,
            "ID": project.eventsWu.id,
            "WorkUnitID": project.eventsWu.workUnitId,
            "Filter": "7",
            "Origin": "Manual",
          }),
        ]),
        makeXmlElement(name: "ObjectExclusionList"),
        makeXmlElement(name: "GameSyncExclusionList"),
      ]
    )
  );
  await project.soundBanksWu.save();
}
