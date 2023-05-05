

import 'dart:io';

import 'package:path/path.dart';
import 'package:tuple/tuple.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/pak/pakExtractor.dart';
import '../../fileTypeUtils/pak/pakRepacker.dart';
import '../../fileTypeUtils/yax/xmlToYax.dart';
import 'dirs.dart';
import 'newQuestConfig.dart';
import 'utils.dart';

Future<Tuple2<Directory, Directory>> _extractCorehapDatAndPak() async {
  var corehapDatDir = (await extractDats([File(corehapDatPath)]))[0];
  var corehapPakPath = join(corehapDatDir.path, "core_hap.pak");
  var pakFiles = await extractPakFiles(corehapPakPath, yaxToXml: true);
  var pakDir = dirname(pakFiles[0]);
  return Tuple2(corehapDatDir, Directory(pakDir));
}

void _incrementXmlArrayLength(XmlElement list, [int increment = 1]) {
  const lengthTags = { "count", "size", "length" };
  if (list.childElements.isEmpty)
    throw Exception("Cannot increment length of empty array");
  var lengthElement = list.childElements.firstWhere((e) => lengthTags.contains(e.name.local));
  if (lengthElement.childElements.isNotEmpty)
    throw Exception("Length element has children");
  if (!isInt(lengthElement.text))
    throw Exception("Length element is not an integer");
  var length = int.parse(lengthElement.text);
  length += increment;
  lengthElement.innerText = length.toString();
}

Future<void> _addQuestDefinition(NewQuestConfig questConfig, Directory pakDir) async {
  var xmlPath = join(pakDir.path, corehapQuestDefXml);
  var xmlFile = File(xmlPath);
  var xml = XmlDocument.parse(await xmlFile.readAsString());
  var root = xml.rootElement;
  
  var node = root.findElements("node").first;
  var newXml = makeXmlElement(name: "child", children: [
    makeXmlElement(name: "tag", text: questConfig.id.toString()),
    makeXmlElement(name: "count", text: "5"),
    makeChildXml(tag: "name", value: questConfig.name.us),
    makeChildXml(tag: "bind", value: questConfig.bind),
    makeChildXml(tag: "owner", value: questConfig.owner),
    makeChildXml(tag: "comment", value: questConfig.comment),
    makeChildXml(tag: "client", value: questConfig.client),
  ]);
  node.children.add(newXml);
  _incrementXmlArrayLength(node);

  var xmlStr = "${xml.toXmlString(pretty: true, indent: "\t")}\n";
  await xmlFile.writeAsString(xmlStr);
  await xmlFileToYaxFile(xmlFile.path);
}

Future<void> _addSceneStateDefinition(NewQuestConfig questConfig, Directory pakDir) async {
  var xmlPath = join(pakDir.path, corehapSceneStateDefXml);
  var xmlFile = File(xmlPath);
  var xml = XmlDocument.parse(await xmlFile.readAsString());
  var root = xml.rootElement;
  
  var node = root.findElements("node").first;
  for (var stage in questConfig.stages) {
    var stageSceneState = stage.stage.toString();
    var newXml = makeChildXml(tag: stageSceneState);
    node.children.add(newXml);
  }
  _incrementXmlArrayLength(node, questConfig.stages.length);

  var xmlStr = "${xml.toXmlString(pretty: true, indent: "\t")}\n";
  await xmlFile.writeAsString(xmlStr);
  await xmlFileToYaxFile(xmlFile.path);
}

XmlElement? _findChildByTag(XmlElement child, String value) {
  var res = child.findElements("child")
    .where((e) {
      var tag = e.findElements("tag").first;
      return tag.name.local == "tag" && tag.text == value;
    })
    .toList();
  return res.isEmpty ? null : res.first;
}

int? _parseQuestName(String questname) {
  var match = RegExp(r"\d+").firstMatch(questname);
  if (match == null)
    return null;
  return int.parse(match.group(0)!);
}

Future<void> _addQuestStateBind(NewQuestConfig questConfig, Directory pakDir) async {
  var xmlPath = join(pakDir.path, corehapQuestToggleXml);
  var xmlFile = File(xmlPath);
  var xml = XmlDocument.parse(await xmlFile.readAsString());
  var root = xml.rootElement;
  var node = root.findElements("node").first;

  for (var bindGroup in questConfig.phaseQuestBinds) {
    var globalPhaseEl = _findChildByTag(node, bindGroup.globalPhase.value)!;
    for (var phaseBind in bindGroup.phaseQuestBinds) {
      var phaseEl = _findChildByTag(globalPhaseEl, phaseBind.phase)!;
      var questTagName = phaseBind.isOn ? "QuestOn" : "QuestOff";
      var questEl = _findChildByTag(phaseEl, questTagName);
      if (questEl == null) {
        questEl = makeChildXml(tag: questTagName, value: "");
        phaseEl.children.add(questEl);
        _incrementXmlArrayLength(phaseEl);
        print("Warning: Untested code path, please check the generated XML file for correctness");
      }
      var questValue = questEl.findElements("value").first;
      var questValueText = questValue.text;
      bool questHasParantheses = questValueText.isNotEmpty && questValueText[0] == '"';
      if (questHasParantheses) {
        assert(questValueText[questValueText.length - 1] == '"');
        questValueText = questValueText.substring(1, questValueText.length - 1);
      }
      var quests = questValueText.split(" ");
      int insertIndex = -1;
      int? curQuestId;
      do {
        insertIndex++;
        curQuestId = _parseQuestName(quests[insertIndex]);
      } while (insertIndex + 1 < quests.length && (curQuestId == null || curQuestId < questConfig.id.id));
      if (insertIndex < quests.length && _parseQuestName(quests[insertIndex]) == questConfig.id.id)
        throw Exception("Quest ${questConfig.id} already exists in phase ${phaseBind.phase}");
      var insertText = "*${questConfig.id}";
      quests.insert(insertIndex, insertText);
      questValueText = quests.join(" ");
      if (questHasParantheses)
        questValueText = '"$questValueText"';
      questValue.innerText = questValueText;
    }
  }

  var xmlStr = "${xml.toXmlString(pretty: true, indent: "\t")}\n";
  await xmlFile.writeAsString(xmlStr);
  await xmlFileToYaxFile(xmlFile.path);
}

Future<void> _repackDatAndPak(Directory datDir, Directory pakDir) async {
  await repackPak(pakDir.path);
  await exportDat(datDir.path);
}

Future<void> addHapXmlData(NewQuestConfig questConfig) async {
  var datAndPakDir = await _extractCorehapDatAndPak();
  var datDir = datAndPakDir.item1;
  var pakDir = datAndPakDir.item2;
  await _addQuestDefinition(questConfig, pakDir);
  await _addSceneStateDefinition(questConfig, pakDir);
  await _addQuestStateBind(questConfig, pakDir);
  await _repackDatAndPak(datDir, pakDir);
}
