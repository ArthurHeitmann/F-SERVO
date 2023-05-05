

import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/bxm/bxmReader.dart';
import '../../fileTypeUtils/bxm/bxmWriter.dart';
import 'chaIO.dart';
import 'dirs.dart';
import 'newQuestConfig.dart';
import 'qchIO.dart';
import 'questStages.dart';
import 'utils.dart';

Future<Directory> _extractCoregmDat() async {
  var res = await extractDats([File(coregmPath)]);
  return res[0];
}

Future<void> _repackCoregmDat(Directory coregmDir) async {
  await exportDat(coregmDir.path);
}

Future<void> _addBxmMsgQueInfo(NewQuestConfig questConfig, Directory coregmDir) async {
  var bxmPath = join(coregmDir.path, msgQueInfoBxmName);
  var xmlPath = "${withoutExtension(bxmPath)}.xml";
  await convertBxmFileToXml(bxmPath, xmlPath);
  var xmlFile = File(xmlPath);
  var xml = XmlDocument.parse(await xmlFile.readAsString());

  var root = xml.rootElement;
  var lastQuest = root.childElements.last;
  var lastQuestId = int.parse(lastQuest.name.local.split("_")[1]);
  
  var newQuestId = lastQuestId + 1;
  var newXml = makeXmlElement(name: "Quest_$newQuestId", children: [
    makeXmlElement(name: "QuestId", text: questConfig.id.id.toString().padLeft(3, "0")),
  ]);
  int i = 0;
  for (var groupedStage in questConfig.stages) {
    if (groupedStage.description == null)
      continue;
    var stage = groupedStage.stage;
    if (stage.id == null)
      continue;
    var newStateXml = makeXmlElement(name: "State_$i", children: [
      makeXmlElement(name: "State", text: stage.id.toString()),
      makeXmlElement(name: "StateId", text: stage is QuestStageWithIndex ? stage.index.toString() : "-1"),
      makeXmlElement(name: "ChildId", text: "-1"),
      makeXmlElement(name: "ChildStateId", text: "-1"),
    ]);
    newXml.children.add(newStateXml);
    i++;
  }
  root.children.add(newXml);

  var xmlStr = "${xml.toXmlString(pretty: true, indent: "\t")}\n";
  await xmlFile.writeAsString(xmlStr);
  await convertXmlToBxmFile(xmlPath, bxmPath);
}

int _getChapterIndex(int globalPhase, String? phase, List<ChaEntry> chapters) {
  if (phase == null) {
    return chapters
      .lastWhere((ch) => ch.globalPhase == globalPhase)
      .index;
  }
  return chapters
    .firstWhere((ch) => ch.globalPhase == globalPhase && ch.phaseName == phase)
    .index;
}

const _chapterIndexOffset = -2;
Future<void> _addQuestChapterData(NewQuestConfig questConfig, Directory coregmDir) async {
  var chaPath = join(coregmDir.path, chapterDataName);
  var cha = await ChaFile.readFromFile(File(chaPath));
  var qchPath = join(coregmDir.path, questChapterDataName);
  var qch = await QchFile.readFromFile(File(qchPath));
  
  var newQchEntry = QchEntry(questConfig.id.id, List.filled(QchEntry.flagsCount, 0));
  for (var chapterBind in questConfig.chapterQuestBinds) {
    int startIndex = _getChapterIndex(chapterBind.globalPhase.intValue, chapterBind.phaseStart, cha.entries) + _chapterIndexOffset;
    int endIndex = _getChapterIndex(chapterBind.globalPhase.intValue, chapterBind.phaseEnd, cha.entries) + _chapterIndexOffset;
    startIndex = max(startIndex, 0);
    endIndex = min(endIndex, cha.entries.length - 1);
    for (int i = startIndex; i <= endIndex; i++) {
      newQchEntry.flags[i] = chapterBind.playerFlag.value;
    }
  }
  int insertIndex = qch.entries.indexWhere((e) => e.questId > questConfig.id.id);
  if (insertIndex == -1)
    insertIndex = qch.entries.length;
  qch.entries.insert(insertIndex, newQchEntry);
  qch.header.count++;

  await qch.writeToFile(File(qchPath));
}

Future<void> addCoregmData(NewQuestConfig questConfig) async {
  var coregmDatDir = await _extractCoregmDat();
  
  await _addBxmMsgQueInfo(questConfig, coregmDatDir);
  await _addQuestChapterData(questConfig, coregmDatDir);
  
  await _repackCoregmDat(coregmDatDir);
}
