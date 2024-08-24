

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/audio/bnkIO.dart';
import '../../fileTypeUtils/audio/bnkNotes.dart';
import '../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../fileTypeUtils/audio/wwiseObjectPath.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../fileTypeUtils/yax/japToEng.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../utils.dart';
import 'elements/hierarchyBaseElements.dart';
import 'elements/wwiseAttenuations.dart';
import 'elements/wwiseBus.dart';
import 'elements/wwiseEffect.dart';
import 'elements/wwiseEvents.dart';
import 'elements/wwiseGameParameters.dart';
import 'elements/wwiseSoundBanks.dart';
import 'elements/wwiseStates.dart';
import 'elements/wwiseSwitchOrState.dart';
import 'elements/wwiseSwitches.dart';
import 'elements/wwiseTriggers.dart';
import 'elements/wwiseWorkUnit.dart';
import 'wwiseAudioFilesPrepare.dart';
import 'wwiseElement.dart';
import 'wwiseElementBase.dart';
import 'wwiseIdGenerator.dart';


class WwiseProjectGenerator {
  final String projectName;
  final String projectPath;
  final BnkFile bnk;
  late final Map<int, List<String>> bnkFolders;
  final List<BnkHircChunkBase> _hircChunks;
  final Map<String, WwiseElementBase> _elements = {};
  final Map<int, String> shortToFullId = {};
  final WwiseIdGenerator idGen;
  final List<WwiseLog> _logs = [];
  final Map<int, WwiseAudioFile> soundFiles = {};
  final Map<int, WwiseSwitchOrStateGroup> stateGroups = {};
  final Map<int, WwiseSwitchOrStateGroup> switchGroups = {};
  final Map<int, WwiseElement> gameParameters = {};
  final Map<int, WwiseElement> buses = {};
  late final Map<int, BnkState> bnkStateChunks = {};
  late final WwiseElement defaultConversion;
  late final WwiseElement defaultBus;
  late final WwiseWorkUnit attenuationsWu;
  late final WwiseWorkUnit amhWu;
  late final WwiseWorkUnit effectsWu;
  late final WwiseWorkUnit eventsWu;
  late final WwiseWorkUnit gameParametersWu;
  late final WwiseWorkUnit imhWu;
  late final WwiseWorkUnit mmhWu;
  late final WwiseWorkUnit soundBanksWu;
  late final WwiseWorkUnit statesWu;
  late final WwiseWorkUnit switchesWu;
  late final WwiseWorkUnit triggersWu;
  late final String language;

  WwiseProjectGenerator(this.projectName, this.projectPath, this.bnk, this._hircChunks)
    : idGen = WwiseIdGenerator(projectName) {
    var header = bnk.chunks.whereType<BnkHeader>().first;
    language = _languageIds[header.languageId] ?? "SFX";
    var bnkId = header.bnkId;
    var bnkPaths = wwiseBnkToIdObjectPath[projectName] ?? wwiseBnkToIdObjectPath[wemIdsToNames[bnkId]] ?? wwiseIdToObjectPath;
    Map<int, String> joinedBnkPaths = {};
    joinedBnkPaths.addAll(wwiseBnkToIdObjectPath["Init"]!);
    joinedBnkPaths.addAll(bnkPaths);
    bnkFolders = {
      for (var entry in joinedBnkPaths.entries)
        entry.key: entry.value.split("/").where((e) => e.isNotEmpty).toList(),
    };
    for (var state in hircChunksByType<BnkState>())
      bnkStateChunks[state.uid] = state;
  }
  
  static Future<void> generateFromBnk(String bnkPath, String savePath) async {
    try {
      isLoadingStatus.pushIsLoading();
      var projectName = basenameWithoutExtension(bnkPath);
      var projectPath = join(savePath, projectName);
      // clean
      if (await Directory(projectPath).exists()) {
        await Directory(projectPath).delete(recursive: true);
      }
      if (await File(projectPath).exists()) {
        showToast("Error: $projectPath is a file");
        return;
      }
      await Directory(projectPath).create(recursive: true);
      // extract
      var projectZip = await rootBundle.load("assets/new_wwise_project.zip");
      var archive = ZipDecoder().decodeBytes(projectZip.buffer.asUint8List());
      await extractArchiveToDisk(archive, projectPath);
      // rename
      var wprojPath = join(projectPath, "test_project.wproj");
      var wprojPathNew = join(projectPath, "$projectName.wproj");
      await File(wprojPath).rename(wprojPathNew);
      var wprojData = await File(wprojPathNew).readAsString();
      wprojData = wprojData.replaceAll("test_project", projectName);
      await File(wprojPathNew).writeAsString(wprojData);
      // read bnk
      var bnk = BnkFile.read(await ByteDataWrapper.fromFile(bnkPath));
      var hirc = bnk.chunks.whereType<BnkHircChunk>().firstOrNull;
      if (hirc == null) {
        showToast("Error: BNK file has no HIRC chunk");
        return;
      }
      var hircChunks = hirc.chunks;
      // generate
      var generator = WwiseProjectGenerator(projectName, projectPath, bnk, hircChunks);
      await generator.run();
      showToast("Generated wwise project $projectName");
    } catch (e, st) {
      messageLog.add("$e\n$st");
      showToast("Failed to generate Wwise project");
    } finally {
      isLoadingStatus.popIsLoading();
    }
  }

  Future<void> run() async {
    var unknownChunks = hircChunksByType<BnkHircUnknownChunk>().toList();
    if (unknownChunks.isNotEmpty) {
      var chunkTypes = unknownChunks.map((c) => c.type).toSet();
      log(WwiseLogSeverity.warning, "${unknownChunks.length} unknown chunks: ${chunkTypes.join(", ")}");
    }
    await Future.wait([
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Attenuations", _defaultWorkUnit)).then((wu) => attenuationsWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Actor-Mixer Hierarchy", _defaultWorkUnit)).then((wu) => amhWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Effects", _defaultWorkUnit)).then((wu) => effectsWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Events", _defaultWorkUnit)).then((wu) => eventsWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Game Parameters", _defaultWorkUnit)).then((wu) => gameParametersWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Interactive Music Hierarchy", _defaultWorkUnit)).then((wu) => imhWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Master-Mixer Hierarchy", _defaultWorkUnit)).then((wu) => mmhWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "SoundBanks", _defaultWorkUnit)).then((wu) => soundBanksWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "States", _defaultWorkUnit)).then((wu) => statesWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Switches", _defaultWorkUnit)).then((wu) => switchesWu = wu),
      WwiseWorkUnit.emptyFromXml(this, join(projectPath, "Triggers", _defaultWorkUnit)).then((wu) => triggersWu = wu),
    ]);
    var wprojPath = join(projectPath, "$projectName.wproj");
    var wprojDoc = XmlDocument.parse(await File(wprojPath).readAsString());
    var defaultConversionElement = wprojDoc.rootElement.findAllElements("DefaultConversion").first;
    defaultConversion = WwiseElement.fromXml("", this, defaultConversionElement);
    assert (defaultConversion.name == "Vorbis Quality High");

    var mmhWuId = mmhWu.id;
    var busElement = mmhWu.defaultChildren.first.findAllElements("Bus").first;
    defaultBus = WwiseElement.fromXml(mmhWuId, this, busElement);

    await Future.wait([
      saveSwitchesIntoWu(this),
      saveStatesIntoWu(this),
      saveGameParametersIntoWu(this),
      saveTriggersIntoWu(this),
      saveEffectsIntoWu(this),
      saveAttenuationsIntoWu(this),
      saveBusesIntoWu(this),
      prepareWwiseAudioFiles(this).then((files) => soundFiles.addAll(files)),
      makeWwiseSoundBank(this),
    ]);
    idGen.init(this);
    
    await saveHierarchyBaseElements(this);
    await saveEventsHierarchy(this);
  }

  Iterable<BnkHircChunkBase> get hircChunks => _hircChunks;
  Iterable<T> hircChunksByType<T>() => _hircChunks.whereType<T>();
  T? hircChunkById<T>(int id) => _hircChunks.where((e) => e.uid == id).firstOrNull as T?;

  WwiseElementBase? lookupElement({String? idV4, int? idFnv}) {
    if (idV4 != null) {
      return _elements[idV4];
    } else if (idFnv != null) {
      idGen.markIdUsed(idFnv);
      return _elements[shortToFullId[idFnv]];
    }
    throw ArgumentError("idV4 or idFnv must be provided");
  }
  void putElement(WwiseElementBase element, {int? idFnv}) {
    _elements.putIfAbsent(element.id, () => element);
    if (idFnv != null) {
      shortToFullId.putIfAbsent(idFnv, () => element.id);
    }
  }

  void log(WwiseLogSeverity severity, String message) {
    messageLog.add(message);
    _logs.add(WwiseLog(severity, message));
  }

  String? getComment(int? id) {
    if (id == null)
      return null;
    var comment = wwiseIdToNote[id];
    if (comment == null)
      return null;
    if (true) // TODO config
      return japToEng[comment] ?? comment;
    // return comment;
  }
}

enum WwiseLogSeverity {
  info,
  warning,
  error,
}

class WwiseLog {
  final WwiseLogSeverity severity;
  final String message;

  WwiseLog(this.severity, this.message);
}

const _defaultWorkUnit = "Default Work Unit.wwu";

const _languageIds = {
  0x00: "SFX",
  0x01: "Arabic",
  0x02: "Bulgarian",
  0x03: "Chinese(HK)",
  0x04: "Chinese(PRC)",
  0x05: "Chinese(Taiwan)",
  0x06: "Czech",
  0x07: "Danish",
  0x08: "Dutch",
  0x09: "English(Australia)",
  0x0A: "English(India)",
  0x0B: "English(UK)",
  0x0C: "English(US)",
  0x0D: "Finnish",
  0x0E: "French(Canada)",
  0x0F: "French(France)",
  0x10: "German",
  0x11: "Greek",
  0x12: "Hebrew",
  0x13: "Hungarian",
  0x14: "Indonesian",
  0x15: "Italian",
  0x16: "Japanese",
  0x17: "Korean",
  0x18: "Latin",
  0x19: "Norwegian",
  0x1A: "Polish",
  0x1B: "Portuguese(Brazil)",
  0x1C: "Portuguese(Portugal)",
  0x1D: "Romanian",
  0x1E: "Russian",
  0x1F: "Slovenian",
  0x20: "Spanish(Mexico)",
  0x21: "Spanish(Spain)",
  0x22: "Spanish(US)",
  0x23: "Swedish",
  0x24: "Turkish",
  0x25: "Ukrainian",
  0x26: "Vietnamese",
};
