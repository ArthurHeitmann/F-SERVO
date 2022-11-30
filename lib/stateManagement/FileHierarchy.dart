import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import '../fileTypeUtils/audio/waiExtracter.dart';
import '../fileTypeUtils/dat/datExtractor.dart';
import '../fileTypeUtils/ruby/pythonRuby.dart';
import '../fileTypeUtils/yax/xmlToYax.dart';
import '../fileTypeUtils/yax/yaxToXml.dart';
import '../main.dart';
import '../utils/utils.dart';
import '../widgets/misc/confirmDialog.dart';
import '../widgets/misc/fileSelectionDialog.dart';
import '../widgets/propEditors/xmlActions/XmlActionPresets.dart';
import 'HierarchyEntryTypes.dart';
import 'Property.dart';
import 'nestedNotifier.dart';
import '../fileTypeUtils/pak/pakExtractor.dart';
import 'openFilesManager.dart';
import 'events/statusInfo.dart';
import 'preferencesData.dart';
import 'undoable.dart';
import 'xmlProps/xmlProp.dart';


class OpenHierarchyManager extends NestedNotifier<HierarchyEntry> with Undoable {
  HierarchyEntry? _selectedEntry;

  OpenHierarchyManager() : super([]);

  NestedNotifier parentOf(HierarchyEntry entry) {
    return findRecWhere((e) => e.contains(entry)) ?? this;
  }

  Future<HierarchyEntry> openFile(String filePath, { HierarchyEntry? parent }) async {
    isLoadingStatus.pushIsLoading();

    HierarchyEntry entry;
    // TODO clean this up
    try {
      if (strEndsWithDat(filePath)) {
        if (await File(filePath).exists())
          entry = await openDat(filePath, parent: parent);
        else if (await Directory(filePath).exists())
          entry = await openExtractedDat(filePath, parent: parent);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".pak")) {
        if (await File(filePath).exists())
          entry = await openPak(filePath, parent: parent);
        else if (await Directory(filePath).exists())
          entry = await openExtractedPak(filePath, parent: parent);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".xml")) {
        if (await File(filePath).exists())
          entry = openGenericFile<XmlScriptHierarchyEntry>(filePath, parent, (n, p) => XmlScriptHierarchyEntry(n, p));
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".yax")) {
        if (await File(filePath).exists())
          entry = await openYaxXmlScript(filePath, parent: parent);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".rb")) {
        if (await File(filePath).exists())
          entry = openGenericFile<RubyScriptHierarchyEntry>(filePath, parent, ((n, p) => RubyScriptHierarchyEntry(n, p)));
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".bin") || filePath.endsWith(".mrb")) {
        if (await File(filePath).exists())
          entry = await openBinMrbScript(filePath, parent: parent);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".tmd")) {
        if (await File(filePath).exists())
          entry = openGenericFile<TmdHierarchyEntry>(filePath, parent, (n, p) => TmdHierarchyEntry(n, p),);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".smd")) {
        if (await File(filePath).exists())
          entry = openGenericFile<SmdHierarchyEntry>(filePath, parent, (n ,p) => SmdHierarchyEntry(n, p));
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".mcd")) {
        if (await File(filePath).exists())
          entry = openGenericFile<McdHierarchyEntry>(filePath, parent, (n ,p) => McdHierarchyEntry(n, p));
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".ftb")) {
        if (await File(filePath).exists())
          entry = openGenericFile<FtbHierarchyEntry>(filePath, parent, (n ,p) => FtbHierarchyEntry(n, p));
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".wai")) {
        if (await File(filePath).exists())
          entry = await openWaiFile(filePath);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".wem")) {
        if (await File(filePath).exists())
          entry = openGenericFile<WemHierarchyEntry>(filePath, parent, (n ,p) => WemHierarchyEntry(n, p));
        else
          throw FileSystemException("File not found: $filePath");
      }
      else
        throw FileSystemException("Unsupported file type: $filePath");
      
      undoHistoryManager.onUndoableEvent();
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
    var fileName = path.basename(datPath);
    var datFolder = path.dirname(datPath);
    var datExtractDir = path.join(datFolder, "nier2blender_extracted", fileName);
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

    var datEntry = DatHierarchyEntry(StringProp(fileName), datPath, datExtractDir);
    if (parent != null)
      parent.add(datEntry);
    else
      add(datEntry);

    var existingEntries = findAllRecWhere((entry) => 
      entry is PakHierarchyEntry && entry.path.startsWith(datExtractDir));
    for (var entry in existingEntries)
      parentOf(entry).remove(entry);

    // process DAT files
    List<Future<void>> futures = [];
    datFilePaths ??= await getDatFileList(datExtractDir);
    RubyScriptGroupHierarchyEntry? rubyScriptGroup;
    const supportedFileEndings = { ".pak", "_scp.bin", ".tmd", ".smd", ".mcd", ".ftb" };
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
      rubyScriptGroup.name.value += " (${rubyScriptGroup.length})";
      if (rubyScriptGroup.length > 8)
        rubyScriptGroup.isCollapsed = true;
    }

    return datEntry;
  }

  Future<HierarchyEntry> openExtractedDat(String datDirPath, { HierarchyEntry? parent }) {
    var srcDatDir = path.dirname(path.dirname(datDirPath));
    var srcDatPath = path.join(srcDatDir, path.basename(datDirPath));
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

    var pakFolder = path.dirname(pakPath);
    var pakExtractDir = path.join(pakFolder, "pakExtracted", path.basename(pakPath));
    if (!await Directory(pakExtractDir).exists()) {
      await extractPakFiles(pakPath, yaxToXml: true);
    }
    var pakEntry = PakHierarchyEntry(StringProp(pakPath.split(Platform.pathSeparator).last), pakPath, pakExtractDir);
    var parentEntry = findPakParentGroup(path.basename(pakPath)) ?? parent;
    if (parentEntry != null)
      parentEntry.add(pakEntry);
    else
      add(pakEntry);
    await pakEntry.readGroups(path.join(pakExtractDir, "0.xml"), parent);

    var existingEntries = findAllRecWhere((entry) =>
      entry is XmlScriptHierarchyEntry && entry.path.startsWith(pakExtractDir));
    for (var childXml in existingEntries)
      parentOf(childXml).remove(childXml);

    var pakInfoJson = await getPakInfoData(pakExtractDir);
    for (var yaxFile in pakInfoJson) {
      var xmlFile = yaxFile["name"].replaceAll(".yax", ".xml");
      var xmlFilePath = path.join(pakExtractDir, xmlFile);
      int existingEntryI = existingEntries.indexWhere((entry) => (entry as FileHierarchyEntry).path == xmlFilePath);
      if (existingEntryI != -1) {
        pakEntry.add(existingEntries[existingEntryI]);
        continue;
      }
      if (!await File(xmlFilePath).exists()) {
        showToast("Failed to open $xmlFilePath");
      }

      var xmlEntry = XmlScriptHierarchyEntry(StringProp(xmlFile), xmlFilePath);
      if (await File(xmlFilePath).exists())
        await xmlEntry.readMeta();
      else if (await File(path.join(pakExtractDir, yaxFile["name"])).exists()) {
        await yaxFileToXmlFile(path.join(pakExtractDir, yaxFile["name"]));
        await xmlEntry.readMeta();
      }
      else
        throw FileSystemException("File not found: $xmlFilePath");
      pakEntry.add(xmlEntry);
    }

    return pakEntry;
  }

  Future<HierarchyEntry> openExtractedPak(String pakDirPath, { HierarchyEntry? parent }) {
    var srcPakDir = path.dirname(path.dirname(pakDirPath));
    var srcPakPath = path.join(srcPakDir, path.basename(pakDirPath));
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
    var entry = make(StringProp(path.basename(filePath)), filePath);
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
      String? waiExtractDir = await fileSelectionDialog(getGlobalContext(), isFile: false, title: "Select WAI Extract Directory");
      if (waiExtractDir == null) {
        showToast("WAI Extract Directory not set");
        throw Exception("WAI Extract Directory not set");
      }
      prefs.waiExtractDir!.value = waiExtractDir;
    }
    var waiExtractDir = prefs.waiExtractDir!.value;
    
    var waiEntry = WaiHierarchyEntry(StringProp(path.basename(waiPath)), waiPath, waiExtractDir);

    // create EXTRACTION_COMPLETED file, to mark as extract dir
    bool noExtract = true;
    var extractedFile = File(path.join(waiExtractDir, "EXTRACTION_COMPLETED"));
    if (!await extractedFile.exists())
      noExtract = false;
    var wai = await waiEntry.readWaiFile();
    var structure = await extractWaiWsps(wai, waiPath, waiExtractDir, noExtract);
    if (!noExtract)
      await extractedFile.writeAsString("Delete this file to re-extract files");
    waiEntry.structure = structure;
    add(waiEntry);
    return waiEntry;
  }

  @override
  void remove(HierarchyEntry child) {
    _removeRec(child);
    super.remove(child);
  }

  @override
  void clear() {
    if (isEmpty) return;
    for (var child in this)
      _removeRec(child);
    super.clear();
  }

  void removeAny(HierarchyEntry child) {
    _removeRec(child);
    parentOf(child).remove(child);
  }

  void _removeRec(HierarchyEntry entry) {
    if (entry is FileHierarchyEntry)
      areasManager.releaseFile(entry.path);
    if (entry == _selectedEntry)
      selectedEntry = null;
      
    for (var child in entry) {
      _removeRec(child);
    }
  }

  Future<XmlScriptHierarchyEntry> addScript(HierarchyEntry parent, { String? filePath, String? parentPath }) async {
    if (filePath == null) {
      assert(parentPath != null);
      var pakFiles = await getPakInfoData(parentPath!);
      var newFileName = "${pakFiles.length}.xml";
      filePath = path.join(parentPath, newFileName);
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
    var entry = XmlScriptHierarchyEntry(StringProp("New Script"), filePath);
    parent.add(entry);

    showToast("Remember to check the \"pak file type\"");

    return entry;
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
    for (var entry in this)
      entry.setCollapsedRecursive(false, true);
  }
  
  void collapseAll() {
    for (var entry in this)
      entry.setCollapsedRecursive(true, true);
  }

  HierarchyEntry? get selectedEntry => _selectedEntry;

  set selectedEntry(HierarchyEntry? value) {
    if (value == _selectedEntry)
      return;
    _selectedEntry?.isSelected = false;
    assert(value == null || value.isSelectable);
    _selectedEntry = value;
    _selectedEntry?.isSelected = true;
    notifyListeners();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = OpenHierarchyManager();
    snapshot.overrideUuid(uuid);
    snapshot.replaceWith(map((e) => e.takeSnapshot() as HierarchyEntry).toList());
    snapshot._selectedEntry = _selectedEntry != null ? _selectedEntry?.takeSnapshot() as HierarchyEntry : null;
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as OpenHierarchyManager;
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
    if (entry.selectedEntry != null)
      selectedEntry = findRecWhere((e) => entry.selectedEntry!.uuid == e.uuid);
    else
      selectedEntry = null;
  }
}

final openHierarchyManager = OpenHierarchyManager();
final StringProp openHierarchySearch = StringProp("")
  ..addListener(() {
    for (var entry in openHierarchyManager) {
      entry.setIsVisibleWithSearchRecursive(false);
      entry.computeIsVisibleWithSearchFilter();
      entry.propagateVisibility();
    }
  });
