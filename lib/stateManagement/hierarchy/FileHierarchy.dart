import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';
import 'package:xml/xml.dart';

import '../../fileSystem/ExtractedFilesManager.dart';
import '../../fileSystem/VirtualFileSystem.dart';
import '../../fileTypeUtils/audio/bnkExtractor.dart';
import '../../fileTypeUtils/audio/bnkIO.dart';
import '../../fileTypeUtils/audio/waiExtractor.dart';
import '../../fileTypeUtils/bxm/bxmReader.dart';
import '../../fileTypeUtils/cpk/cpk.dart';
import '../../fileTypeUtils/cpk/cpkExtractor.dart';
import '../../fileTypeUtils/ctx/ctxExtractor.dart';
import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/pak/pakExtractor.dart';
import '../../fileTypeUtils/ruby/pythonRuby.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../fileTypeUtils/utils/ByteDataWrapperRA.dart';
import '../../fileTypeUtils/xml/xmlExtension.dart';
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
import 'HierarchyEntryTypes.dart';
import 'types/BnkHierarchyEntry.dart';
import 'types/BxmHierarchyEntry.dart';
import 'types/CpkHierarchyEntry.dart';
import 'types/CtxHierarchyEntry.dart';
import 'types/DatHierarchyEntry.dart';
import 'types/EstHierarchyEntry.dart';
import 'types/FtbHierarchyEntry.dart';
import 'types/McdHierarchyEntry.dart';
import 'types/PakHierarchyEntry.dart';
import 'types/PassiveFileHierarchyEntry.dart';
import 'types/RubyScriptHierarchyEntry.dart';
import 'types/SaveSlotDataHierarchyEntry.dart';
import 'types/SmdHierarchyEntry.dart';
import 'types/TmdHierarchyEntry.dart';
import 'types/UidHierarchyData.dart';
import 'types/WaiHierarchyEntries.dart';
import 'types/WmbHierarchyData.dart';
import 'types/WtaHierarchyEntry.dart';
import 'types/WtbHierarchyEntry.dart';
import 'types/XmlScriptHierarchyEntry.dart';
import '../../fileSystem/FileSystem.dart';


class OpenHierarchyManager with HasUuid, HierarchyEntryBase implements Disposable {
  final ValueNotifier<HierarchyEntry?> _selectedEntry = ValueNotifier(null);
  final StringProp search = StringProp("", fileId: null);
  ValueListenable<HierarchyEntry?> get selectedEntry => _selectedEntry;
  ValueNotifier<bool> filteredTreeIsDirty = ValueNotifier(false);
  ValueNotifier<bool> collapsedTreeIsDirty = ValueNotifier(false);
  late void Function() _onSearchChangedThrottled;

  OpenHierarchyManager() {
    children.addListener(() => filteredTreeIsDirty.value = true);
    _onSearchChangedThrottled = debounce(() => filteredTreeIsDirty.value = true, 500);
    search.addListener(() {
      var (overThreshold, _) = hasOverXChildren(500*1000);
      if (overThreshold)
        _onSearchChangedThrottled();
      else
        filteredTreeIsDirty.value = true;
    });
  }

  HierarchyEntryBase parentOf(HierarchyEntryBase entry) {
    return findRecWhere((e) => e.children.contains(entry)) ?? this;
  }

  Future<HierarchyEntry?> openFile(String filePath, { HierarchyEntry? parent }) async {
    isLoadingStatus.pushIsLoading();

    HierarchyEntry? entry;
    try {
      List<Tuple2<Iterable<String>, Future<HierarchyEntry?> Function()>> hierarchyPresets = [
        Tuple2(datExtensions, () async {
          if (await FS.i.existsFile(filePath)) {
            if (basename(filePath).startsWith("SlotData"))  // special case for save data
              return openGenericFile<SaveSlotDataHierarchyEntry>(filePath, parent, (n, p) => SaveSlotDataHierarchyEntry(n, p));
            return await openDat(filePath, parent: parent);
          } else if (await FS.i.existsDirectory(filePath))
            return await openExtractedDat(filePath, parent: parent);
          else
            throw FileSystemException("File not found: $filePath");
        }),
        Tuple2([".pak"], () async {
          if (await FS.i.existsFile(filePath))
            return await openPak(filePath, parent: parent);
          else if (await FS.i.existsDirectory(filePath))
            return await openExtractedPak(filePath, parent: parent);
          else
            throw FileSystemException("File not found: $filePath");
        }),
        Tuple2(
          [".xml"],
          () async => await openXmlFile(filePath, parent: parent)
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
        // Tuple2(
        //   [".wai"],
        //   () async => await openWaiFile(filePath)
        // ),
        // Tuple2(
        //   [".wsp"],
        //   () async => openWspFile(filePath)
        // ),
        Tuple2(
          [".bnk"],
          () async => openBnkFile(filePath, parent: parent)
        ),
        Tuple2(
          bxmExtensions, () async => openBxmFile(filePath, parent: parent)
        ),
        Tuple2(
          [".wta", ".wta_extracted"],
          () async => openWtaFile(filePath, parent: parent)
        ),
        Tuple2(
          [".wtb", ".wtb_extracted"],
          () async => openWtbFile(filePath, parent: parent)
        ),
        Tuple2(
          [".cpk"],
          () => openCpkFile(filePath, parent: parent)
        ),
        Tuple2(
          [".est", ".sst"],
          () async => openGenericFile<EstHierarchyEntry>(filePath, parent, (n, p) => EstHierarchyEntry(n, p))
        ),
        Tuple2(
          [".ctx"],
          () async => openCtxFile(filePath, parent: parent)
        ),
        Tuple2(
          [".uid"],
          () async => openGenericFile<UidHierarchyEntry>(filePath, parent, (n, p) => UidHierarchyEntry(n, p))
        ),
        Tuple2(
          [".wmb", ".scr"],
          () async => openGenericFile<WmbHierarchyEntry>(filePath, parent, (n, p) => WmbHierarchyEntry(n, p))
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
    } catch(e, s) {
      print("$e\n$s");
      messageLog.add("Failed to open ${basename(filePath)}");
      return null;
    } finally {
      isLoadingStatus.popIsLoading();
    }

    return entry;
  }

  Future<HierarchyEntry> openDat(String datPath, { HierarchyEntry? parent, String? datExtractDir, bool allowMissingInfoFile = false }) async {
    var existing = findRecWhere((entry) => entry is DatHierarchyEntry && entry.path == datPath);
    if (existing != null)
      return existing;

    // get DAT infos
    var fileName = basename(datPath);
    datExtractDir ??= await ExtractedFilesManager.i.getOrMakeExtracted(datPath, createIfMissing: false);
    DatFiles? datFilePaths;
    var srcDatExists = await FS.i.existsFile(datPath);
    if (!await FS.i.existsDirectory(datExtractDir) && srcDatExists) {
      await extractDatFiles(datPath, shouldExtractPakFiles: true);
    }
    else {
      try {
        datFilePaths = await getDatFileList(datExtractDir, allowMissingInfoFile: allowMissingInfoFile, removeDuplicates: true);
      } catch (e, s) {
        print("$e\n$s");
      }
      //check if extracted folder actually contains all dat files
      var prefs = PreferencesData();
      var shouldExtractDatFiles = prefs.datReplaceOnExtract!.value;
      if (!shouldExtractDatFiles)
        shouldExtractDatFiles = datFilePaths == null;
      if (!shouldExtractDatFiles)
        shouldExtractDatFiles = datFilePaths!.files.isNotEmpty && await Future.any(datFilePaths.files.map((name) async => !await FS.i.existsFile(name)));
      if (shouldExtractDatFiles) {
        await extractDatFiles(datPath, shouldExtractPakFiles: true);
      }
      else if ((datFilePaths?.version ?? 1) < currentDatVersion && srcDatExists) {
        await updateDatInfoFileOriginalOrder(datPath, datExtractDir);
      }
    }

    var datEntry = DatHierarchyEntry(StringProp(fileName, fileId: null), datPath, datExtractDir, srcDatExists: srcDatExists);
    if (parent != null) {
      datEntry.isCollapsed.value = true;
      parent.add(datEntry);
    } else {
      add(datEntry);
    }

    await datEntry.loadChildren(datFilePaths?.files);

    return datEntry;
  }

  Future<HierarchyEntry> openExtractedDat(String datDirPath, { HierarchyEntry? parent }) {
    var srcDatPath = ExtractedFilesManager.i.getSourceOf(datDirPath);
    return openDat(srcDatPath, parent: parent, datExtractDir: datDirPath, allowMissingInfoFile: true);
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
    if (!await FS.i.existsDirectory(pakExtractDir)) {
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
      if (!await FS.i.existsFile(xmlFilePath)) {
        showToast("Failed to open $xmlFilePath");
      }

      var xmlEntry = XmlScriptHierarchyEntry(StringProp(xmlFile, fileId: null), xmlFilePath);
      if (await FS.i.existsFile(xmlFilePath))
        await xmlEntry.readMeta();
      else if (await FS.i.existsFile(join(pakExtractDir, yaxFile["name"]))) {
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
    if (!await FS.i.existsFile(xmlFilePath)) {
      await yaxFileToXmlFile(yaxFilePath);
    }
    return openGenericFile<XmlScriptHierarchyEntry>(xmlFilePath,parent, (n, p) => XmlScriptHierarchyEntry(n, p));
  }

  Future<HierarchyEntry> openXmlFile(String xmlFilePath, { HierarchyEntry? parent }) async {
    if (bxmExtensions.any((ext) => withoutExtension(xmlFilePath).endsWith(ext)))
      return openGenericFile<BxmHierarchyEntry>(withoutExtension(xmlFilePath), parent, (n, p) => BxmHierarchyEntry(n, p, xmlPath: xmlFilePath));
    if (!RegExp(r"^\d+$").hasMatch(basenameWithoutExtension(xmlFilePath))) {
      var pathNoExt = withoutExtension(xmlFilePath);
      for (var ext in bxmExtensions) {
        var bxmPath = pathNoExt + ext;
        if (await FS.i.existsFile(bxmPath))
          return openGenericFile<BxmHierarchyEntry>(bxmPath, parent, (n, p) => BxmHierarchyEntry(n, p, xmlPath: xmlFilePath));
      }
    }
    return openGenericFile<XmlScriptHierarchyEntry>(xmlFilePath, parent, (n, p) => XmlScriptHierarchyEntry(n, p));
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

    if (!await FS.i.existsFile(rbPath)) {
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
    var extractedFile = join(waiExtractDir, "EXTRACTION_COMPLETED");
    if (!await FS.i.existsFile(extractedFile))
      noExtract = false;
    var wai = await waiData.loadWai();
    var structure = await extractWaiWsps(wai, waiPath, waiExtractDir, noExtract);
    if (!noExtract)
      await FS.i.writeAsString(extractedFile, "Delete this file to re-extract files");
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
    var bnkExtractDir = await ExtractedFilesManager.i.getOrMakeExtracted(bnkPath);
    bool noExtract = false;
    var extractedFile = join(bnkExtractDir, "EXTRACTION_COMPLETED");
    if (await FS.i.existsFile(extractedFile))
      noExtract = true;
    var wemFiles = await extractBnkWems(bnk, bnkExtractDir, noExtract);
    FS.i.associatedFileWith(bnkPath, bnkExtractDir);
    await FS.i.writeAsString(extractedFile, "Delete this file to re-extract files");

    var bnkEntry = BnkHierarchyEntry(StringProp(basename(bnkPath), fileId: null), bnkPath, bnkExtractDir, bnk);

    var wemParentEntry = BnkSubCategoryParentHierarchyEntry("WEM files");
    bnkEntry.add(wemParentEntry);
    wemParentEntry.addAll(wemFiles.map((e) => WemHierarchyEntry(
      StringProp(basename(e.path), fileId: null),
      e.path,
      e.id,
      OptionalWemData(bnkPath, WemSource.bnk, isStreamed: e.isPrefetched, isPrefetched: e.isPrefetched)
    )));
    if (wemFiles.length > 8)
      wemParentEntry.isCollapsed.value = true;

    await bnkEntry.generateHierarchy(basenameWithoutExtension(bnkPath), (parent?.children.length ?? 0) >= 4);

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

    if (!await FS.i.existsFile(bxmEntry.xmlPath) && isDesktop)
      convertBxmFileToXml(bxmPath, bxmEntry.xmlPath);
    
    return bxmEntry;
  }

  Future<HierarchyEntry> openWtaFile(String wtaPath, { HierarchyEntry? parent }) async {
    var existing = findRecWhere((entry) => entry is WtaHierarchyEntry && entry.path == wtaPath);
    if (existing != null)
      return existing;
    
    var wtaEntry = WtaHierarchyEntry(StringProp(basename(wtaPath).replaceAll("_extracted", ""), fileId: null), wtaPath);
    if (parent != null)
      parent.add(wtaEntry);
    else
      add(wtaEntry);

    return wtaEntry;
  }

  Future<HierarchyEntry> openWtbFile(String wtaPath, { HierarchyEntry? parent }) async {
    var existing = findRecWhere((entry) => entry is WtbHierarchyEntry && entry.path == wtaPath);
    if (existing != null)
      return existing;

    var wtaEntry = WtbHierarchyEntry(StringProp(basename(wtaPath).replaceAll("_extracted", ""), fileId: null), wtaPath);
    if (parent != null)
      parent.add(wtaEntry);
    else
      add(wtaEntry);

    return wtaEntry;
  }
  
  Future<HierarchyEntry?> openCpkFile(String filePath, {HierarchyEntry? parent}) async {
    if (FS.i.useVirtualFs) {
      var cpkFile = await ByteDataWrapperRA.fromFile(filePath);
      var cpkEntry = CpkHierarchyEntry(StringProp(basename(filePath), fileId: null), filePath, cpkFile);
      if (parent != null)
        parent.add(cpkEntry);
      else
        add(cpkEntry);
      
      var cpk = await Cpk.read(cpkFile);
      var cpkDir = "\$opened${VirtualFileSystem.separator}${basename(filePath)}";
      FS.i.associatedFileWith(filePath, cpkDir);
      unawaited((() async {
        HierarchyEntry getOrMakeFolder(HierarchyEntry parent, List<String> path) {
          if (path.isEmpty)
            return parent;
          var name = path[0];
          var folder = parent.children
            .whereType<CpkFolderHierarchyEntry>()
            .where((e) => e.name.value == name)
            .firstOrNull;
          if (folder == null) {
            folder = CpkFolderHierarchyEntry(StringProp(name, fileId: null));
            parent.add(folder);
          }
          if (path.length == 1)
            return folder;
          return getOrMakeFolder(folder, path.sublist(1));
        }
        Future<void> extractDat(CpkFile datFile,String datPath) async {
          var fileBytes = await datFile.readData(cpkFile);
          await FS.i.write(datPath, fileBytes);
          await extractDatFiles(datPath);
        }
        for (var file in cpk.files) {
          var dir = join(cpkDir, file.path);
          await FS.i.createDirectory(dir);
          var filePath = join(dir, file.name);
          var folderEntry = getOrMakeFolder(cpkEntry, file.path.split(VirtualFileSystem.separator).where((p) => p.isNotEmpty).toList());
          if (strEndsWithDat(file.name)) {
            var extractedDir = await ExtractedFilesManager.i.getOrMakeExtracted(filePath, createIfMissing: false);
            var datEntry = DatHierarchyEntry(StringProp(file.name, fileId: null), filePath, extractedDir);
            datEntry.beforeLoadChildren = () => extractDat(file, filePath);
            datEntry.needsToLoadChildren = true;
            datEntry.isCollapsed.value = true;
            folderEntry.add(datEntry);
          } else {
            var fileBytes = await file.readData(cpkFile);
            await FS.i.write(filePath, fileBytes);
            var newEntry = await openFile(filePath, parent: folderEntry);
            if (newEntry == null) {
              newEntry = PassiveFileHierarchyEntry(StringProp(file.name, fileId: null), filePath);
              folderEntry.add(newEntry);
            }
          }
        }
        void sortEntry(HierarchyEntry e) {
          e.sortChildren((a, b) {
            if (a.priority != b.priority)
              return b.priority - a.priority;
            return a.name.value.toLowerCase().compareTo(b.name.value.toLowerCase());
          });
          for (var child in e.children) {
            sortEntry(child);
          }
        }
        sortEntry(cpkEntry);
      })());

      return cpkEntry;
    } else {
      var extractedDir = await extractCpkWithPrompt(filePath);
      if (extractedDir != null)
        revealFileInExplorer(extractedDir);
      return null;
    }
  }
  
  Future<HierarchyEntry?> openCtxFile(String filePath, {HierarchyEntry? parent}) async {
    List<String> wtbFiles = [];
    var extractedDir = await ExtractedFilesManager.i.getOrMakeExtracted(filePath, createIfMissing: false);
    bool shouldExtract = !await FS.i.existsDirectory(extractedDir);
    if (!shouldExtract) {
      wtbFiles = await FS.i.listFiles(extractedDir)
        .where((file) => file.endsWith(".wtb"))
        .toList();
      shouldExtract = wtbFiles.isEmpty;
    }
    if (shouldExtract) {
      wtbFiles = await extractCtx(filePath, extractedDir);
    }

    var entry = CtxHierarchyEntry(StringProp(basename(filePath), fileId: null), filePath, extractedDir);
    if (parent != null)
      parent.add(entry);
    else
      add(entry);
    
    for (var wtbFile in wtbFiles) {
      await openWtbFile(wtbFile, parent: entry);
    }

    return entry;
  }

  @override
  void add(HierarchyEntry child) {
    super.add(child);
    if (child is FileHierarchyEntry && !FS.i.isVirtual(child.path)) {
      var prefs = PreferencesData();
      var lastFiles = prefs.lastHierarchyFiles!.value.toList();
      lastFiles.remove(child.path);
      lastFiles.insert(0, child.path);
      lastFiles = lastFiles.take(100).toList();
      prefs.lastHierarchyFiles!.value = lastFiles;
    }
  }

  @override
  void remove(HierarchyEntry child, { bool dispose = false }) {
    _removeRec(child, freeFiles: dispose);
    super.remove(child, dispose: dispose);
    _release(child);
  }

  @override
  void clear() {
    if (children.isEmpty)
      return;
    for (var child in children) {
      _removeRec(child, freeFiles: true);
      child.dispose();
      _release(child);
    }
    super.clear();
    filteredTreeIsDirty.value = true;
  }

  void _release(HierarchyEntry child) {
    if (child is FileHierarchyEntry)
      FS.i.releaseFile(child.path);
    if (child is ExtractableHierarchyEntry)
      FS.i.releaseFolder(child.extractedPath);
  }

  void removeAny(HierarchyEntry child) {
    _removeRec(child, freeFiles: true);
    parentOf(child).remove(child, dispose: true);
  }

  void _removeRec(HierarchyEntry entry, { bool freeFiles = false }) {
    if (freeFiles && entry is FileHierarchyEntry)
      areasManager.releaseFile(entry.path);
    if (entry == _selectedEntry.value)
      setSelectedEntry(null);
      
    for (var child in entry.children) {
      _removeRec(child, freeFiles: freeFiles);
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
      if (await FS.i.existsFile(filePath))
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
    await FS.i.createFile(filePath);
    var doc = XmlDocument();
    doc.children.add(XmlDeclaration([XmlAttribute(XmlName("version"), "1.0"), XmlAttribute(XmlName("encoding"), "utf-8")]));
    doc.children.add(content.toXml());
    var xmlStr = doc.toPrettyString();
    await FS.i.writeAsString(filePath, xmlStr);
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
    await FS.i.delete(script.path);
    var yaxPath = "${script.path.substring(0, script.path.length - 4)}.yax";
    if (await FS.i.existsFile(yaxPath))
      await FS.i.delete(yaxPath);
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
          print("Duplicate parent-child relationship: ${parentMap[child]!.name.value}[${parentMap[child]!.uuid.substring(0,6)}] -> ${child.name.value} (child of ${entry.name.value}[${entry.uuid.substring(0,6)}])");
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
  void dispose() {
    super.dispose();
    _selectedEntry.dispose();
    search.dispose();
    filteredTreeIsDirty.dispose();
    collapsedTreeIsDirty.dispose();
  }
}

final openHierarchyManager = OpenHierarchyManager();
