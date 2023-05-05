

import 'package:path/path.dart';

import 'dirs.dart';
import 'localizedString.dart';
import 'mcdDataLightWeight.dart';
import 'newQuestConfig.dart';
import 'questStages.dart';
import 'utils.dart';

Future<void> _addQuestNameMcdData(QuestId questId, LocalizedString questName) async {
  var mcdDats = await getFilteredDats(mcdsDir, mcdDatQuestNamePrefix);
  var mcdDatDirs = await extractDats(mcdDats, includeDtts: true);
  var nameKey = "PAUSE_QUEST_NAME_$questId";
  print("Adding to ${mcdDatDirs.length} MCDs: $nameKey");
  const fontId = 36;
  for (var mcdDatDir in mcdDatDirs) {
    var fileSuffix = basenameWithoutExtension(mcdDatDir.path).substring(mcdDatQuestNamePrefix.length);
    var questNameStr = questName.getFromFileSuffix(fileSuffix);

    var mcd = await McdData.fromMcdFile(join(mcdDatDir.path, mcdNameQuestNames));
    var newEvent = mcd.addEvent();
    newEvent.name = nameKey;
    newEvent.paragraphs.add(McdParagraph(
      fontId, [McdLine(questNameStr)]
    ));
    await mcd.save();

    await exportDat(mcdDatDir.path);
  }
}

Future<void> addMcdData(NewQuestConfig questConfig) async {
  print("Adding MCD data");
  await _addQuestNameMcdData(questConfig.id, questConfig.name);
}
