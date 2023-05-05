
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

import '../../fileTypeUtils/tmd/tmdReader.dart';
import '../../fileTypeUtils/tmd/tmdWriter.dart';
import 'dirs.dart';
import 'localizedString.dart';
import 'newQuestConfig.dart';
import 'questStages.dart';
import 'utils.dart';

Future<void> _addQuestName(QuestId questId, LocalizedString name) async {
  var tmdDats = await getFilteredDats(tmdsDir, tmdDatQuestNamePrefix);
  var tmdDatDirs = await extractDats(tmdDats);
  var nameKey = "PAUSE_QUEST_NAME_$questId";
  print("Adding to ${tmdDatDirs.length} TMDs: $nameKey");
  for (var tmdDatDir in tmdDatDirs) {
    var fileSuffix = basenameWithoutExtension(tmdDatDir.path).substring(tmdDatQuestNamePrefix.length);
    var questName = name.getFromFileSuffix(fileSuffix);
    var tmdPath = join(tmdDatDir.path, "$tmdDatQuestNamePrefix.tmd");
    var tmdEntries = await readTmdFile(tmdPath);
    var entries = tmdEntries.map((e) => Tuple2(e.id, e.text)).toList();
    entries.add(Tuple2(nameKey, questName));
    tmdEntries = entries.map((e) => TmdEntry.fromStrings(e.item1, e.item2)).toList();
    await saveTmd(tmdEntries, tmdPath);
    await exportDat(tmdDatDir.path);
  }
}

Future<void> _addQuestStages(QuestId questId, List<QuestStageWithDescription> stages) async {
  var tmdDats = await getFilteredDats(tmdsDir, tmdDatQuestStagesPrefix);
  var tmdDatDirs = await extractDats(tmdDats);
  print("Adding to ${tmdDatDirs.length} TMDs: ${stages.length} stages");
  for (var tmdDatDir in tmdDatDirs) {
    var fileSuffix = basenameWithoutExtension(tmdDatDir.path).substring(tmdDatQuestStagesPrefix.length);
    var tmdPath = join(tmdDatDir.path, "$tmdDatQuestStagesPrefix.tmd");
    var tmdEntries = await readTmdFile(tmdPath);
    var entries = tmdEntries.map((e) => Tuple2(e.id, e.text)).toList();
    for (var stage in stages) {
      if (stage.description == null)
        continue;
      var stageKey = "PAUSE_QUEST_HELP_${stage.stage.toString().toUpperCase()}";
      var stageDescription = stage.description!.getFromFileSuffix(fileSuffix);
      entries.add(Tuple2(stageKey, stageDescription));
    }
    tmdEntries = entries.map((e) => TmdEntry.fromStrings(e.item1, e.item2)).toList();
    await saveTmd(tmdEntries, tmdPath);
    await exportDat(tmdDatDir.path);
  }
}

Future<void> addTmdData(NewQuestConfig questConfig) async {
  print("Adding TMD data");
  await _addQuestName(questConfig.id, questConfig.name);
  await _addQuestStages(questConfig.id, questConfig.stages);
}
