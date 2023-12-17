import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';
import 'package:xml/xml.dart';

import '../../background/wemFilesIndexer.dart';
import '../../fileTypeUtils/audio/bnkExtractor.dart';
import '../../fileTypeUtils/audio/bnkIO.dart';
import '../../fileTypeUtils/audio/waiExtractor.dart';
import '../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../fileTypeUtils/bxm/bxmReader.dart';
import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/pak/pakExtractor.dart';
import '../../fileTypeUtils/ruby/pythonRuby.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../fileTypeUtils/yax/xmlToYax.dart';
import '../../fileTypeUtils/yax/yaxToXml.dart';
import '../../main.dart';
import '../../utils/Disposable.dart';
import '../../utils/utils.dart';
import '../../widgets/filesView/types/xml/xmlActions/XmlActionPresets.dart';
import '../../widgets/misc/confirmCancelDialog.dart';
import '../../widgets/misc/confirmDialog.dart';
import '../../widgets/misc/fileSelectionDialog.dart';
import '../Property.dart';
import '../events/statusInfo.dart';
import '../hasUuid.dart';
import '../openFiles/openFilesManager.dart';
import '../openFiles/types/WaiFileData.dart';
import '../openFiles/types/WemFileData.dart';
import '../openFiles/types/xml/xmlProps/xmlProp.dart';
import '../preferencesData.dart';
import '../undoable.dart';
import 'HierarchyEntryTypes.dart';
import 'types/BnkHierarchyEntry.dart';
import 'types/BxmHierarchyEntry.dart';
import 'types/DatHierarchyEntry.dart';
import 'types/EstHierarchyEntry.dart';
import 'types/FtbHierarchyEntry.dart';
import 'types/McdHierarchyEntry.dart';
import 'types/PakHierarchyEntry.dart';
import 'types/RubyScriptHierarchyEntry.dart';
import 'types/SaveSlotDataHierarchyEntry.dart';
import 'types/SmdHierarchyEntry.dart';
import 'types/TmdHierarchyEntry.dart';
import 'types/WaiHierarchyEntries.dart';
import 'types/WtaHierarchyEntry.dart';
import 'types/WtbHierarchyEntry.dart';
import 'types/XmlScriptHierarchyEntry.dart';


class OpenHierarchyManager with HasUuid, Undoable, HierarchyEntryBase implements Disposable {
  final ValueNotifier<HierarchyEntry?> _selectedEntry = ValueNotifier(null);
  ValueListenable<HierarchyEntry?> get selectedEntry => _selectedEntry;
  ValueNotifier<bool> treeViewIsDirty = ValueNotifier(false);

  OpenHierarchyManager() {
    children.addListener(() => treeViewIsDirty.value = true);
  }

  HierarchyEntryBase parentOf(HierarchyEntryBase entry) {
    return (findRecWhere((e) => e.children.contains(entry)) ?? this) as HierarchyEntryBase;
  }

  Future<HierarchyEntry?> openFile(String filePath, { HierarchyEntry? parent }) async {
    isLoadingStatus.pushIsLoading();

    HierarchyEntry? entry;
    try {
      List<Tuple2<Iterable<String>, Future<HierarchyEntry?> Function()>> hierarchyPresets = [
        Tuple2(datExtensions, () async {
          if (await File(filePath).exists()) {
            if (basename(filePath).startsWith("SlotData"))  // special case for save data
              return openGenericFile<SaveSlotDataHierarchyEntry>(filePath, parent, (n, p) => SaveSlotDataHierarchyEntry(n, p));
            return await openDat(filePath, parent: parent);
          } else if (await Directory(filePath).exists())
            return await openExtractedDat(filePath, parent: parent);
          else
            throw FileSystemException("File not found: $filePath");
        }),
        Tuple2([".pak"], () async {
          if (await File(filePath).exists())
            return await openPak(filePath, parent: parent);
          else if (await Directory(filePath).exists())
            return await openExtractedPak(filePath, parent: parent);
          else
            throw FileSystemException("File not found: $filePath");
        }),
        Tuple2(
          [".xml"],
          () async => openGenericFile<XmlScriptHierarchyEntry>(filePath, parent, 
            (n, p) => XmlScriptHierarchyEntry(n, p, preferVsCode: PreferencesData().preferVsCode?.value ?? false))
        ),
        Tuple2(
          [".yax"],
          () async => await openYaxXmlScript(filePath, parent: parent)
        ),
        Tuple2(
          [".rb"],
          () async => openGenericFile<RubyScriptHierarchyEntry>(filePath, parent, ((n, p) => RubyScriptHierarchyEntry(n, p)))
        ),
        Tuple2(
          [".bin", ".mrb"], () async => await openBinMrbScript(filePath, parent: parent)
        ),
        Tuple2(
          [".tmd"],
          () async => openGenericFile<TmdHierarchyEntry>(filePath, parent, (n, p) => TmdHierarchyEntry(n, p))
        ),
        Tuple2(
          [".smd"],
          () async => openGenericFile<SmdHierarchyEntry>(filePath, parent, (n ,p) => SmdHierarchyEntry(n, p))
        ),
        Tuple2(
          [".mcd"],
          () async => openGenericFile<McdHierarchyEntry>(filePath, parent, (n ,p) => McdHierarchyEntry(n, p))
        ),
        Tuple2(
          [".ftb"],
          () async => openGenericFile<FtbHierarchyEntry>(filePath, parent, (n ,p) => FtbHierarchyEntry(n, p))
        ),
        Tuple2(
          [".wai"],
          () async => await openWaiFile(filePath)
        ),
        Tuple2(
          [".wsp"],
          () async => openWspFile(filePath)
        ),
        Tuple2(
          [".bnk"],
          () async => openBnkFile(filePath, parent: parent)
        ),
        Tuple2(
          bxmExtensions, () async => openBxmFile(filePath, parent: parent)
        ),
        Tuple2(
          [".wta"],
          () async => openWtaFile(filePath, parent: parent)
        ),
        Tuple2(
          [".wtb"],
          () async => openWtbFile(filePath, parent: parent)
        ),
        // Tuple2(
        //   [".cpk"],
        //   () async => openCpkFile(filePath, parent: parent)
        // ),
        Tuple2(
          [".est", ".sst"],
          () async => openGenericFile<EstHierarchyEntry>(filePath, parent, (n, p) => EstHierarchyEntry(n, p))
        ),
      ];

      for (var preset in hierarchyPresets) {
        if (preset.item1.any((ext) => filePath.endsWith(ext))) {
          entry = await preset.item2();
          break;
        }
      }
      if (entry == null) {
        messageLog.add("${basename(filePath)} not opened");
        return null;
      }
    } finally {
      isLoadingStatus.popIsLoading();
    }

    return entry;
  }

  Future<HierarchyEntry> openDat(String datPath, { HierarchyEntry? parent }) async {
    var existing = findRecWhere((entry) => entry is DatHierarchyEntry && entry.path == datPath);
    if (existing != null)
      return existing;

    // get DAT infos
    var fileName = basename(datPath);
    var datFolder = dirname(datPath);
    var datExtractDir = join(datFolder, "nier2blender_extracted", fileName);
    List<String>? datFilePaths;
    if (!await Directory(datExtractDir).exists()) {
      await extractDatFiles(datPath, shouldExtractPakFiles: true);
    }
    else {
      datFilePaths = await getDatFileList(datExtractDir);
      //check if extracted folder actually contains all dat files
      if (await Future.any(
        datFilePaths.map((name) async 
          => !await File(name).exists()))) {
        await extractDatFiles(datPath, shouldExtractPakFiles: true);
      }
    }

    var datEntry = DatHierarchyEntry(StringProp(fileName, fileId: null), datPath, datExtractDir);
    if (parent != null)
      parent.add(datEntry);
    else
      add(datEntry);

    var existingEntries = findAllRecWhere((entry) =>
      entry is FileHierarchyEntry && entry.path.startsWith(datExtractDir));
    for (var entry in existingEntries)
      parentOf(entry).remove(entry);

    // process DAT files
    List<Future<void>> futures = [];
    datFilePaths ??= await getDatFileList(datExtractDir);
    RubyScriptGroupHierarchyEntry? rubyScriptGroup;
    const supportedFileEndings = { ".pak", "_scp.bin", ".tmd", ".smd", ".mcd", ".ftb", ".bnk", ".bxm", ".wta", ".wtb", ".est", ".sst" };
    for (var file in datFilePaths) {
      if (supportedFileEndings.every((ending) => !file.endsWith(ending)))
        continue;
      int existingEntryI = existingEntries.indexWhere((entry) => (entry as FileHierarchyEntry).path == file);
      if (existingEntryI != -1) {
        datEntry.add(existingEntries[existingEntryI]);
        continue;
      }
      if (file.endsWith("_scp.bin")) {
        if (rubyScriptGroup == null) {
          rubyScriptGroup = RubyScriptGroupHierarchyEntry();
          datEntry.add(rubyScriptGroup);
        }
        futures.add(openBinMrbScript(file, parent: rubyScriptGroup));
      }
      else
        futures.add(openFile(file, parent: datEntry));
    }

    await Future.wait(futures);

    if (rubyScriptGroup != null) {
      rubyScriptGroup.name.value += " (${rubyScriptGroup.children.length})";
      if (rubyScriptGroup.children.length > 8)
        rubyScriptGroup.isCollapsed.value = true;
    }

    return datEntry;
  }

  Future<HierarchyEntry> openExtractedDat(String datDirPath, { HierarchyEntry? parent }) {
    var srcDatDir = dirname(dirname(datDirPath));
    var srcDatPath = join(srcDatDir, basename(datDirPath));
    return openDat(srcDatPath, parent: parent);
  }
  
  HapGroupHierarchyEntry? findPakParentGroup(String fileName) {
    var match = pakGroupIdMatcher.firstMatch(fileName);
    if (match == null)
      return null;
    var groupId = int.parse(match.group(1)!, radix: 16);
    var parentGroup = findRecWhere((entry) => entry is HapGroupHierarchyEntry && entry.id == groupId) as HapGroupHierarchyEntry?;
    return parentGroup;
  }

  Future<HierarchyEntry> openPak(String pakPath, { HierarchyEntry? parent }) async {
    var existing = findRecWhere((entry) => entry is PakHierarchyEntry && entry.path == pakPath);
    if (existing != null)
      return existing;

    var pakFolder = dirname(pakPath);
    var pakExtractDir = join(pakFolder, "pakExtracted", basename(pakPath));
    if (!await Directory(pakExtractDir).exists()) {
      await extractPakFiles(pakPath, yaxToXml: true);
    }
    var pakEntry = PakHierarchyEntry(StringProp(pakPath.split(Platform.pathSeparator).last, fileId: null), pakPath, pakExtractDir);
    var parentEntry = findPakParentGroup(basename(pakPath)) ?? parent;
    if (parentEntry != null)
      parentEntry.add(pakEntry);
    else
      add(pakEntry);
    await pakEntry.readGroups(join(pakExtractDir, "0.xml"), parent);

    var existingEntries = findAllRecWhere((entry) =>
      entry is XmlScriptHierarchyEntry && entry.path.startsWith(pakExtractDir));
    for (var childXml in existingEntries)
      parentOf(childXml).remove(childXml);

    var pakInfoJson = await getPakInfoData(pakExtractDir);
    for (var yaxFile in pakInfoJson) {
      var xmlFile = yaxFile["name"].replaceAll(".yax", ".xml");
      var xmlFilePath = join(pakExtractDir, xmlFile);
      int existingEntryI = existingEntries.indexWhere((entry) => (entry as FileHierarchyEntry).path == xmlFilePath);
      if (existingEntryI != -1) {
        pakEntry.add(existingEntries[existingEntryI]);
        continue;
      }
      if (!await File(xmlFilePath).exists()) {
        showToast("Failed to open $xmlFilePath");
      }

      var xmlEntry = XmlScriptHierarchyEntry(StringProp(xmlFile, fileId: null), xmlFilePath);
      if (await File(xmlFilePath).exists())
        await xmlEntry.readMeta();
      else if (await File(join(pakExtractDir, yaxFile["name"])).exists()) {
        await yaxFileToXmlFile(join(pakExtractDir, yaxFile["name"]));
        await xmlEntry.readMeta();
      }
      else
        throw FileSystemException("File not found: $xmlFilePath");
      pakEntry.add(xmlEntry);
    }

    return pakEntry;
  }

  Future<HierarchyEntry> openExtractedPak(String pakDirPath, { HierarchyEntry? parent }) {
    var srcPakDir = dirname(dirname(pakDirPath));
    var srcPakPath = join(srcPakDir, basename(pakDirPath));
    return openPak(srcPakPath, parent: parent);
  }

  Future<HierarchyEntry> openYaxXmlScript(String yaxFilePath, { HierarchyEntry? parent }) async {
    var xmlFilePath = "${yaxFilePath.substring(0, yaxFilePath.length - 4)}.xml";
    if (!await File(xmlFilePath).exists()) {
      await yaxFileToXmlFile(yaxFilePath);
    }
    return openGenericFile<XmlScriptHierarchyEntry>(xmlFilePath,parent, (n, p) => XmlScriptHierarchyEntry(n, p));
  }

  HierarchyEntry openGenericFile<T extends FileHierarchyEntry>(String filePath, HierarchyEntry? parent, T Function(StringProp n, String p) make) {
    var existing = findRecWhere((entry) => entry is T && entry.path == filePath);
    if (existing != null)
      return existing;
    var entry = make(StringProp(basename(filePath), fileId: null), filePath);
    if (parent != null)
      parent.add(entry);
    else
      add(entry);
    
    return entry;
  }

  Future<HierarchyEntry> openBinMrbScript(String binFilePath, { HierarchyEntry? parent }) async {
    var rbPath = "$binFilePath.rb";

    var existing = findRecWhere((entry) => entry is RubyScriptHierarchyEntry && entry.path == rbPath);
    if (existing != null)
      return existing;

    if (!await File(rbPath).exists()) {
      await binFileToRuby(binFilePath);
    }

    return openGenericFile<RubyScriptHierarchyEntry>(rbPath, parent, (n, p) => RubyScriptHierarchyEntry(n, p));
  }

  Future<HierarchyEntry> openWaiFile(String waiPath) async {
    var existing = findRecWhere((entry) => entry is WaiHierarchyEntry && entry.path == waiPath);
    if (existing != null)
      return existing;
    
    if (!waiPath.contains("WwiseStreamInfo")) {
      showToast("Only WwiseStreamInfo.wai files are supported");
      throw Exception("Only WwiseStreamInfo.wai files are supported");
    }

    var prefs = PreferencesData();
    if (prefs.waiExtractDir!.value.isEmpty) {
      String? waiExtractDir = await fileSelectionDialog(getGlobalContext(), selectionType: SelectionType.folder, title: "Select WAI Extract Directory");
      if (waiExtractDir == null) {
        showToast("WAI Extract Directory not set");
        throw Exception("WAI Extract Directory not set");
      }
      prefs.waiExtractDir!.value = waiExtractDir;
    }
    var waiExtractDir = prefs.waiExtractDir!.value;

    var waiData = areasManager.openFileAsHidden(waiPath) as WaiFileData;
    await waiData.load();
    
    var waiEntry = WaiHierarchyEntry(StringProp(basename(waiPath), fileId: null), waiPath, waiExtractDir, waiData.uuid);
    add(waiEntry);

    // create EXTRACTION_COMPLETED file, to mark as extract dir
    bool noExtract = true;
    var extractedFile = File(join(waiExtractDir, "EXTRACTION_COMPLETED"));
    if (!await extractedFile.exists())
      noExtract = false;
    var wai = await waiData.loadWai();
    var structure = await extractWaiWsps(wai, waiPath, waiExtractDir, noExtract);
    if (!noExtract)
      await extractedFile.writeAsString("Delete this file to re-extract files");
    waiEntry.structure = structure;

    // move folders to top of list
    List<WaiChild> topLevelFolders = structure.whereType<WaiChildDir>().toList();
    topLevelFolders.sort((a, b) => a.name.compareTo(b.name));
    structure.removeWhere((child) => child is WaiChildDir);
    for (int i = 0; i < topLevelFolders.length; i++)
      structure.insert(i, topLevelFolders[i]);
    var bgmBnkPath = join(dirname(waiPath), "bgm", "BGM.bnk");
    waiEntry.addAll(structure.map((e) => makeWaiChildEntry(e, bgmBnkPath)));

    return waiEntry;
  }

  HierarchyEntry openWspFile(String wspPath) {
    showToast("Please open WwiseStreamInfo.wai instead", const Duration(seconds: 6));
    throw Exception("Can't open WSP file directly");
  }

  Future<HierarchyEntry> openBnkFile(String bnkPath, { HierarchyEntry? parent }) async {
    var existing = findRecWhere((entry) => entry is BnkHierarchyEntry && entry.path == bnkPath);
    if (existing != null)
      return existing;
    
    // extract BNK WEMs
    var bnk = BnkFile.read(await ByteDataWrapper.fromFile(bnkPath));
    var bnkExtractDirName = "${basename(bnkPath)}_extracted";
    var bnkExtractDir = join(dirname(bnkPath), bnkExtractDirName);
    if (!await Directory(bnkExtractDir).exists())
      await Directory(bnkExtractDir).create(recursive: true);
    bool noExtract = false;
    var extractedFile = File(join(bnkExtractDir, "EXTRACTION_COMPLETED"));
    if (await extractedFile.exists())
      noExtract = true;
    var wemFiles = await extractBnkWems(bnk, bnkExtractDir, noExtract);
    await extractedFile.writeAsString("Delete this file to re-extract files");

    var bnkEntry = BnkHierarchyEntry(StringProp(basename(bnkPath), fileId: null), bnkPath, bnkExtractDir);

    var wemParentEntry = BnkSubCategoryParentHierarchyEntry("WEM files");
    bnkEntry.add(wemParentEntry);
    wemParentEntry.addAll(wemFiles.map((e) => WemHierarchyEntry(
      StringProp(basename(e.item2), fileId: null),
      e.item2,
      e.item1,
      OptionalWemData(bnkPath, WemSource.bnk)
    )));
    if (wemFiles.length > 8)
      wemParentEntry.isCollapsed.value = true;

    var hircChunk = bnk.chunks.whereType<BnkHircChunk>().firstOrNull;
    if (hircChunk != null) {
      Map<int, BnkHircHierarchyEntry> hircEntries = {};
      Map<int, BnkHircHierarchyEntry> actionEntries = {};
      List<BnkHircHierarchyEntry> eventEntries = [];
      Map<String, Set<String>> usedSwitchGroups = {};
      Map<String, Set<String>> usedStateGroups = {};
      Map<String, Set<String>> usedGameParameters = {};
      void addGroupUsage(Map<String, Set<String>> map, String groupName, String entryName) {
        if (!map.containsKey(groupName))
          map[groupName] = {};
        map[groupName]!.add(entryName);
      }
      for (var hirc in hircChunk.chunks) {
        var uidNameLookup = wemIdsToNames[hirc.uid];
        var uidNameStr = uidNameLookup != null ? "_$uidNameLookup" : "";
        String path;
        if (hirc is BnkMusicPlaylist)
          path = "$bnkPath#p=${hirc.uid}";
        else
          path = "$bnkPath#id=${hirc.uid}";
        List<int> parentId = [];
        List<int> childIds = [];
        List<(bool, List<String>)> props = [];
        if (hirc is BnkHircChunkWithBaseParamsGetter) {
          var hircChunk = hirc as BnkHircChunkWithBaseParamsGetter;
          var baseParams = hircChunk.getBaseParams();
          parentId.add(baseParams.directParentID);
          if (parentId.last == 0)
            parentId.removeLast();
          for (var stateGroup in baseParams.states.stateGroup) {
            var stateGroupId = randomId();
            var groupName = wemIdsToNames[stateGroup.ulStateGroupID] ?? stateGroup.ulStateGroupID.toString();
            var stateGroupEntry = BnkHircHierarchyEntry(StringProp("StateGroup_$groupName", fileId: null), "", stateGroupId, "StateGroup", [hirc.uid]);
            hircEntries[stateGroupId] = stateGroupEntry;
            for (var state in stateGroup.state) {
              var stateName = wemIdsToNames[state.ulStateID] ?? state.ulStateID.toString();
              addGroupUsage(usedStateGroups, groupName, stateName);
              var stateId = randomId();
              var childId = state.ulStateInstanceID;
              if (hircEntries.containsKey(childId)) {
                var childState = hircEntries[childId]!;
                childState.name.value += " = $stateName";
                childState.parentIds.add(stateGroupId);
              }
              else {
                var stateEntry = BnkHircHierarchyEntry(StringProp("State_$stateName", fileId: null), "", stateId, "State", [stateGroupId], [childId]);
                hircEntries[stateId] = stateEntry;
              }
            }
          }
          Future<void> addWemChild(int srcId) async {
            var srcName = wemIdsToNames[srcId];
            if (srcName == null)
              srcName = srcId.toString();
            else
              srcName = "${srcId}_$srcName";
            var path = await wemFilesLookup.lookupWithAdditionalDir(srcId, bnkExtractDir);
            if (hircEntries.containsKey(srcId)) {
              var child = hircEntries[srcId]!;
              child.parentIds.add(hirc.uid);
            }
            else {
              var srcEntry = BnkHircHierarchyEntry(StringProp(srcName, fileId: null), path ?? "", srcId, "WEM", [hirc.uid]);
              srcEntry.optionalFileInfo = OptionalWemData(bnkPath, WemSource.bnk);
              hircEntries[srcId] = srcEntry;
            }
          }
          if (hircChunk is BnkMusicTrack) {
            for (var src in hircChunk.sources) {
              var srcId = src.sourceID;
              await addWemChild(srcId);
            }
          }
          if (hircChunk is BnkSound) {
            var srcId = hircChunk.bankData.mediaInformation.sourceID;
            await addWemChild(srcId);
          }
          if (hircChunk is BnkMusicSwitch) {
            var groups = hircChunk.arguments
              .map((a) => wemIdsToNames[a.ulGroup] ?? a.ulGroup.toString())
              .toList();
            void parseSwitchNode(int parentId, BnkTreeNode node, int depth) {
              // if (node.key == 0 && node.audioNodeId == null) {
              //   for (var child in node.children)
              //     parseSwitchNode(parentId, child, depth + 1);
              //   return;
              // }
              var nodeId = randomId();
              var nodeName = "${groups[depth]}=${wemIdsToNames[node.key] ?? node.key.toString()}";
              var nodeEntry = BnkHircHierarchyEntry(StringProp(nodeName, fileId: null), "", nodeId, "SwitchNode", [parentId], node.audioNodeId != null ? [node.audioNodeId!] : []);
              hircEntries[nodeId] = nodeEntry;
              for (var child in node.children)
                parseSwitchNode(nodeId, child, depth + 1);
            }
            for (var node in hircChunk.decisionTree[0].children)
              parseSwitchNode(hirc.uid, node, 0);
          }
          BnkAkMeterInfo? meterInfo;
          if (hircChunk is BnkMusicSegment)
            meterInfo = hircChunk.musicParams.meterInfo;
          else if (hircChunk is BnkMusicPlaylist)
            meterInfo = hircChunk.musicTransParams.musicParams.meterInfo;
          else if (hircChunk is BnkMusicSwitch)
            meterInfo = hircChunk.musicTransParams.musicParams.meterInfo;
          if (meterInfo != null) {
            const defaultTempo = 120.0;
            const defaultBeatValue = 4;
            const defaultNumBeatsPerBar = 4;
            const defaultGridPeriod = 1000.0;
            const defaultGridOffset = 0.0;
            if (meterInfo.fTempo != defaultTempo || meterInfo.uBeatValue != defaultBeatValue || meterInfo.uNumBeatsPerBar != defaultNumBeatsPerBar || meterInfo.fGridPeriod != defaultGridPeriod || meterInfo.fGridOffset != defaultGridOffset) {
              props.addAll([
                (false, ["Tempo", "Time Signature", "Grid Period", "Grid Offset"]),
                (true, [
                    "${meterInfo.fTempo}",
                    "${meterInfo.uNumBeatsPerBar} / ${meterInfo.uBeatValue}",
                    "${meterInfo.fGridPeriod}",
                    "${meterInfo.fGridOffset}"
                ]),
              ]);
            }
          }
          props.addAll(BnkHircHierarchyEntry.makePropsFromParams(baseParams.iniParams.propValues, baseParams.iniParams.rangedPropValues));
        }
        else if (hirc is BnkAction) {
          childIds = [hirc.initialParams.idExt];
          if (hirc.initialParams.idExt != 0 && !hircEntries.containsKey(hirc.initialParams.idExt)) {
            var targetName = wemIdsToNames[hirc.initialParams.idExt] ?? "Target_${hirc.initialParams.idExt.toString()}";
            var targetId = randomId();
            var child = BnkHircHierarchyEntry(StringProp(targetName, fileId: null), "", targetId, "ActionTarget", [hirc.uid]);
            hircEntries[targetId] = child;
          }
          if (uidNameStr.isEmpty)
            uidNameStr = actionTypes[hirc.ulActionType] ?? "";
          props.addAll(BnkHircHierarchyEntry.makePropsFromParams(hirc.initialParams.propValues, hirc.initialParams.rangedPropValues));
          var specificParams = hirc.specificParams;
          if (specificParams is BnkSwitchActionParams) {
            var groupName = wemIdsToNames[specificParams.ulSwitchGroupID] ?? specificParams.ulSwitchGroupID.toString();
            var switchValue = wemIdsToNames[specificParams.ulSwitchStateID] ?? specificParams.ulSwitchStateID.toString();
            addGroupUsage(usedSwitchGroups, groupName, switchValue);
            props.addAll([
              (false, ["Switch Group", "Switch State"]),
              (true, [groupName, switchValue]),
            ]);
          }
          if (specificParams is BnkStateActionParams) {
            var groupName = wemIdsToNames[specificParams.ulStateGroupID] ?? specificParams.ulStateGroupID.toString();
            var stateValue = wemIdsToNames[specificParams.ulTargetStateID] ?? specificParams.ulTargetStateID.toString();
            addGroupUsage(usedStateGroups, groupName, stateValue);
            props.addAll([
              (false, ["State Group", "Target State"]),
              (true, [groupName, stateValue]),
            ]);
          }
          if (specificParams is BnkValueActionParams) {
            if (gameParamActionTypes.contains(hirc.ulActionType & 0xFF00)) {
              var gameParamName = wemIdsToNames[hirc.initialParams.idExt] ?? hirc.initialParams.idExt.toString();
              addGroupUsage(usedGameParameters, gameParamName, "");
              props.addAll([
                (false, ["Game Parameter"]),
                (true, [gameParamName]),
              ]);
            }
            double? base, min, max;
            var valueParams = specificParams.specificParams;
            if (valueParams is BnkGameParameterParams) {
              base = valueParams.base;
              min = valueParams.min;
              max = valueParams.max;
            }
            else if (valueParams is BnkPropActionParams) {
              base = valueParams.base;
              min = valueParams.min;
              max = valueParams.max;
            }
            if (base != null && min != null && max != null) {
              props.addAll([
                (false, ["Value", "(Min)", "(Max)"]),
                (true, ["$base", "$min", "$max"]),
              ]);
            }
          }
        }
        else if (hirc is BnkEvent)
          childIds = hirc.ids;
        else if (hirc is BnkActorMixer)
          childIds = hirc.childIDs;
        else if (hirc is BnkState)
          props.addAll(BnkHircHierarchyEntry.makePropsFromParams(hirc.props));
        else
          continue;

        var chunkType = hirc.runtimeType.toString().replaceFirst("Bnk", "");
        var entryName = "${hirc.uid}_$chunkType$uidNameStr";
        var entry = BnkHircHierarchyEntry(StringProp(entryName, fileId: null), path, hirc.uid, chunkType, parentId, childIds, props);

        if (hirc is BnkEvent) {
          List<BnkHircHierarchyEntry> childActions = [];
          for (var childId in childIds) {
            var child = actionEntries[childId];
            if (child == null) {
              var childName = wemIdsToNames[childId] ?? "Action_$childId";
              child = BnkHircHierarchyEntry(StringProp(childName, fileId: null), "", childId, "Action", [hirc.uid]);
              actionEntries[childId] = child;
            }
            child.parentIds.add(hirc.uid);
            childActions.add(child);
          }
          childActions.sort((a, b) => a.name.value.toLowerCase().compareTo(b.name.value.toLowerCase()));
          for (var actionEntry in childActions)
            entry.add(actionEntry);
          eventEntries.add(entry);
        }
        else if (hirc is BnkAction) {
          actionEntries[hirc.uid] = entry;
          var actionChild = hircEntries[hirc.initialParams.idExt];
          if (actionChild != null) {
            actionChild.usages++;
            if (actionChild.usages > 1)
              actionChild = actionChild.takeSnapshot() as BnkHircHierarchyEntry;
            entry.add(actionChild);
          }
          else {
            var actionChildName = wemIdsToNames[hirc.initialParams.idExt] ?? "Target_${hirc.initialParams.idExt.toString()}";
            var actionChildId = randomId();
            var actionChildEntry = BnkHircHierarchyEntry(StringProp(actionChildName, fileId: null), "", actionChildId, "ActionTarget", [hirc.uid]);
            hircEntries[actionChildId] = actionChildEntry;
            entry.add(actionChildEntry);
          }
        }
        else {
          hircEntries[hirc.uid] = entry;
        }
      }

      for (var entry in hircEntries.entries) {
        var hasChildren = entry.value.childIds.isNotEmpty;
        if (hasChildren) {
          for (var childId in entry.value.childIds) {
            var child = hircEntries[childId];
            if (child == null)
              continue;
            if (child.parentIds.contains(entry.value.id))
              continue;
            child.parentIds.add(entry.value.id);
          }
        }
      }
      var groupUsages = [
        ("Switch Groups", usedSwitchGroups),
        ("State Groups", usedStateGroups),
      ];
      for (var groupUsage in groupUsages) {
        var groupName = groupUsage.$1;
        var groupMap = groupUsage.$2;
        if (groupMap.isEmpty)
          continue;
        var groupParentEntry = BnkSubCategoryParentHierarchyEntry(groupName, isCollapsed: true);
        bnkEntry.add(groupParentEntry);
        var groupEntries = groupMap.entries.toList();
        groupEntries.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
        for (var group in groupEntries) {
          var groupEntry = BnkHircHierarchyEntry(StringProp(group.key, fileId: null), "", randomId(), groupName);
          groupParentEntry.add(groupEntry);
          var groupValues = group.value.toList();
          groupValues.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          for (var entryName in groupValues) {
            var entry = BnkHircHierarchyEntry(StringProp(entryName, fileId: null), "", randomId(), "Group Entry");
            groupEntry.add(entry);
          }
        }
      }
      if (usedGameParameters.isNotEmpty) {
        var gameParamParentEntry = BnkSubCategoryParentHierarchyEntry("Game Parameters", isCollapsed: true);
        bnkEntry.add(gameParamParentEntry);
        var gameParameters = usedGameParameters.keys.toList();
        gameParameters.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        for (var gameParam in gameParameters) {
          var gameParamEntry = BnkHircHierarchyEntry(StringProp(gameParam, fileId: null), "", randomId(), "Game Parameter");
          gameParamParentEntry.add(gameParamEntry);
        }
      }
      var objectHierarchyParentEntry = BnkSubCategoryParentHierarchyEntry("Object Hierarchy");
      bnkEntry.add(objectHierarchyParentEntry);
      int directChildren = 0;
      for (var entry in hircEntries.entries) {
        var hasParent = entry.value.parentIds.isNotEmpty;
        if (hasParent) {
          for (var parentId in entry.value.parentIds.toList()) {
            var parent = hircEntries[parentId];
            if (parent == null) {
              entry.value.parentIds.remove(parentId);
            } else if (!parent.children.contains(entry.value)) {
              var child = entry.value;
              child.usages++;
              if (child.usages > 1)
                child = child.takeSnapshot() as BnkHircHierarchyEntry;
              parent.add(child);
            } else {
              // print("Duplicate parent-child relationship: ${parent.name.value} -> ${entry.value.name.value}");
            }
          }
        }
        else {
          var child = entry.value;
          child.usages++;
          if (child.usages > 1)
            child = child.takeSnapshot() as BnkHircHierarchyEntry;
          objectHierarchyParentEntry.add(child);
          directChildren++;
        }
      }
      if (directChildren > 50)
        objectHierarchyParentEntry.isCollapsed.value = true;
      
      var eventHierarchyParentEntry = BnkSubCategoryParentHierarchyEntry("Event Hierarchy");
      bnkEntry.add(eventHierarchyParentEntry);
      eventEntries.sort((a, b) => a.name.value.toLowerCase().compareTo(b.name.value.toLowerCase()));
      for (var entry in eventEntries)
        eventHierarchyParentEntry.add(entry);
      if (eventEntries.length > 50)
        eventHierarchyParentEntry.isCollapsed.value = true;
    }

    if (parent != null)
      parent.add(bnkEntry);
    else
      add(bnkEntry);
    
    return bnkEntry;
  }

  Future<HierarchyEntry> openBxmFile(String bxmPath, { HierarchyEntry? parent }) async {
    var existing = findRecWhere((entry) => entry is BxmHierarchyEntry && entry.path == bxmPath);
    if (existing != null)
      return existing;
    
    var bxmEntry = BxmHierarchyEntry(StringProp(basename(bxmPath), fileId: null), bxmPath);
    if (parent != null)
      parent.add(bxmEntry);
    else
      add(bxmEntry);

    if (!await File(bxmEntry.xmlPath).exists())
      convertBxmFileToXml(bxmPath, bxmEntry.xmlPath);
    
    return bxmEntry;
  }

  Future<HierarchyEntry> openWtaFile(String wtaPath, { HierarchyEntry? parent }) async {
    var existing = findRecWhere((entry) => entry is WtaHierarchyEntry && entry.path == wtaPath);
    if (existing != null)
      return existing;
    
    // find corresponding wtp file
    var wtpName = "${basenameWithoutExtension(wtaPath)}.wtp";
    var datDir = dirname(wtaPath);
    var dttDir = await findDttDirOfDat(datDir);
    String wtpPath;
    if (dttDir != null)
      wtpPath = join(dttDir, wtpName);
    else {
      wtpPath = join(datDir, wtpName);
      if (!await File(wtpPath).exists()) {
        showToast("Can't find corresponding WTP file");
        throw Exception("Can't find corresponding WTP file");
      }
    }

    var wtaEntry = WtaHierarchyEntry(StringProp(basename(wtaPath), fileId: null), wtaPath, wtpPath);
    if (parent != null)
      parent.add(wtaEntry);
    else
      add(wtaEntry);

    return wtaEntry;
  }

  Future<HierarchyEntry> openWtbFile(String wtaPath, { HierarchyEntry? parent }) async {
    var existing = findRecWhere((entry) => entry is WtaHierarchyEntry && entry.path == wtaPath);
    if (existing != null)
      return existing;

    var wtaEntry = WtbHierarchyEntry(StringProp(basename(wtaPath), fileId: null), wtaPath);
    if (parent != null)
      parent.add(wtaEntry);
    else
      add(wtaEntry);

    return wtaEntry;
  }
  
  // Future<HierarchyEntry?> openCpkFile(String filePath, {HierarchyEntry? parent}) async {
  //   var extractedDir = await extractCpkWithPrompt(filePath);
  //   if (extractedDir != null)
  //     revealFileInExplorer(extractedDir);
  //   return null;
  // }

  @override
  void remove(HierarchyEntry child, { bool dispose = false }) {
    _removeRec(child);
    super.remove(child, dispose: dispose);
  }

  @override
  void clear() {
    if (children.isEmpty)
      return;
    for (var child in children) {
      _removeRec(child);
      child.dispose();
    }
    super.clear();
    treeViewIsDirty.value = true;
  }

  void removeAny(HierarchyEntry child) {
    _removeRec(child);
    parentOf(child).remove(child, dispose: true);
  }

  void _removeRec(HierarchyEntry entry) {
    if (entry is FileHierarchyEntry)
      areasManager.releaseFile(entry.path);
    if (entry == _selectedEntry.value)
      setSelectedEntry(null);
      
    for (var child in entry.children) {
      _removeRec(child);
    }
  }

  Future<void> addScript(HierarchyEntry parent, { String? filePath, String? parentPath }) async {
    if (await confirmOrCancelDialog(getGlobalContext(), title: "Add new XML script?") != true)
      return;
    if (filePath == null) {
      assert(parentPath != null);
      var pakFiles = await getPakInfoData(parentPath!);
      var newIndex = pakFiles
        .map((e) => e["name"])
        .whereType<String>()
        .map((e) => RegExp(r"^(\d+)\.yax$").firstMatch(e))
        .whereType<RegExpMatch>()
        .map((e) => int.parse(e.group(1)!))
        .fold<int>(0, (prev, e) => max(prev, e)) + 1;
      var newFileName = "$newIndex.xml";
      filePath = join(parentPath, newFileName);
      if (await File(filePath).exists())
        filePath = "${randomId()}.xml";
    }

    // create file
    var dummyProp = XmlProp(file: null, tagId: 0, parentTags: []);
    var content = XmlProp.fromXml(
      makeXmlElement(name: "root", children: [
        makeXmlElement(name: "name", text: "New Script"),
        makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
        if (parent is HapGroupHierarchyEntry)
          makeXmlElement(name: "group", text: "0x${parent.id.toRadixString(16)}"),
        makeXmlElement(name: "size", text: "1"),
        (XmlActionPresets.sendCommand.withCxtV(dummyProp).prop() as XmlProp).toXml(),
      ]),
      parentTags: []
    );
    var file = File(filePath);
    await file.create(recursive: true);
    var doc = XmlDocument();
    doc.children.add(XmlDeclaration([XmlAttribute(XmlName("version"), "1.0"), XmlAttribute(XmlName("encoding"), "utf-8")]));
    doc.children.add(content.toXml());
    var xmlStr = "${doc.toXmlString(pretty: true, indent: '\t')}\n";
    await file.writeAsString(xmlStr);
    xmlFileToYaxFile(filePath);
    
    // add file to pakInfo.json
    var yaxPath = "${filePath.substring(0, filePath.length - 4)}.yax";
    await addPakInfoFileData(yaxPath, 3);

    // add to hierarchy
    var entry = XmlScriptHierarchyEntry(StringProp(basename(filePath), fileId: null), filePath);
    await entry.readMeta();
    parent.add(entry);

    showToast("Remember to check the \"pak file type\"");
  }

  Future<void> unlinkScript(XmlScriptHierarchyEntry script, { bool requireConfirmation = true }) async {
    if (requireConfirmation && await confirmDialog(getGlobalContext(), title: "Are you sure?") != true)
      return;
    await removePakInfoFileData(script.path);
    removeAny(script);
  }

  Future<void> deleteScript(XmlScriptHierarchyEntry script) async {
    if (await confirmDialog(getGlobalContext(), title: "Are you sure?") != true)
      return;
    await unlinkScript(script, requireConfirmation: false);
    await File(script.path).delete();
    var yaxPath = "${script.path.substring(0, script.path.length - 4)}.yax";
    if (await File(yaxPath).exists())
      await File(yaxPath).delete();
  }

  void expandAll() {
    for (var entry in children)
      entry.setCollapsedRecursive(false, true);
  }
  
  void collapseAll() {
    for (var entry in children)
      entry.setCollapsedRecursive(true, true);
  }

  setSelectedEntry(HierarchyEntry? value) {
    if (value == _selectedEntry.value)
      return;
    _selectedEntry.value?.isSelected.value = false;
    // assert(value == null || value.isSelectable);
    _selectedEntry.value = value;
    _selectedEntry.value?.isSelected.value = true;
  }

  Map<HierarchyEntry, HierarchyEntry?> generateTmpParentMap() {
    Map<HierarchyEntry, HierarchyEntry?> parentMap = {};
    void generateTmpParentMapRec(HierarchyEntry entry) {
      for (var child in entry.children) {
        if (parentMap.containsKey(child)) {
          print("Duplicate parent-child relationship: ${parentMap[child]!.name.value} -> ${child.name.value} (child of ${entry.name.value})");
          continue;
        }
        parentMap[child] = entry;
        generateTmpParentMapRec(child);
      }
    }
    for (var entry in children) {
      parentMap[entry] = null;
      generateTmpParentMapRec(entry);
    }
    return parentMap;
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = OpenHierarchyManager();
    snapshot.overrideUuid(uuid);
    snapshot.replaceWith(children.map((e) => e.takeSnapshot() as HierarchyEntry).toList());
    snapshot._selectedEntry.value = _selectedEntry.value != null ? _selectedEntry.value?.takeSnapshot() as HierarchyEntry : null;
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as OpenHierarchyManager;
    updateOrReplaceWith(entry.children.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
    if (entry.selectedEntry.value != null)
      setSelectedEntry(findRecWhere((e) => entry.selectedEntry.value!.uuid == e.uuid));
    else
      setSelectedEntry(null);
  }

  @override
  void dispose() {
    super.dispose();
    _selectedEntry.dispose();
    treeViewIsDirty.dispose();
  }
}

final openHierarchyManager = OpenHierarchyManager();
final StringProp openHierarchySearch = StringProp("", fileId: null)
  ..addListener(() {
    for (var entry in openHierarchyManager.children) {
      entry.setIsVisibleWithSearchRecursive(false);
      entry.computeIsVisibleWithSearchFilter();
      entry.propagateVisibility(openHierarchyManager.generateTmpParentMap());
    }
    openHierarchyManager.treeViewIsDirty.value = true;
  });
