import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import '../fileTypeUtils/dat/datExtractor.dart';
import '../fileTypeUtils/ruby/pythonRuby.dart';
import '../fileTypeUtils/yax/yaxToXml.dart';
import '../main.dart';
import '../utils.dart';
import '../widgets/misc/confirmDialog.dart';
import '../widgets/propEditors/xmlActions/XmlActionPresets.dart';
import 'Property.dart';
import 'nestedNotifier.dart';
import '../fileTypeUtils/pak/pakExtractor.dart';
import 'openFileTypes.dart';
import 'openFilesManager.dart';
import 'statusInfo.dart';
import 'undoable.dart';
import 'xmlProps/xmlProp.dart';

final _pakGroupIdMatcher = RegExp(r"^\w+_([a-f0-9]+)_grp\.pak$", caseSensitive: false);

class HierarchyEntry extends NestedNotifier<HierarchyEntry> with Undoable {
  StringProp name;
  final bool isSelectable;
  bool _isSelected = false;
  bool get isSelected => _isSelected;
  final bool isCollapsible;
  bool _isCollapsed = false;
  final bool isOpenable;

  HierarchyEntry(this.name, this.isSelectable, this.isCollapsible, this.isOpenable)
    : super([]);

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }


  set isSelected(bool value) {
    if (value == _isSelected) return;
    _isSelected = value;
    notifyListeners();
  }

  bool get isCollapsed => _isCollapsed;

  set isCollapsed(bool value) {
    if (value == _isCollapsed) return;
    _isCollapsed = value;
    notifyListeners();
  }

  void onOpen() {
    print("Not implemented!");
  }
  
  void setCollapsedRecursive(bool value, [bool setSelf = false]) {
    if (setSelf)
      isCollapsed = value;
    for (var child in this) {
      child.setCollapsedRecursive(value, true);
    }
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = HierarchyEntry(name.takeSnapshot() as StringProp, isSelectable, isCollapsible, isOpenable);
    snapshot.overrideUuidForUndoable(uuid);
    snapshot._isSelected = _isSelected;
    snapshot._isCollapsed = _isCollapsed;
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }

  HierarchyEntry clone() => takeSnapshot() as HierarchyEntry;
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as HierarchyEntry;
    name.restoreWith(entry.name);
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    updateOrReplaceWith(entry.toList(), (obj) => (obj as HierarchyEntry).clone());
  }
}

class FileHierarchyEntry extends HierarchyEntry {
  final String path;

  FileHierarchyEntry(StringProp name, this.path, bool isCollapsible, bool isOpenable)
    : super(name, true, isCollapsible, isOpenable);
  
  @override
  Undoable takeSnapshot() {
    var snapshot = FileHierarchyEntry(name.takeSnapshot() as StringProp, path, isCollapsible, isOpenable);
    snapshot.overrideUuidForUndoable(uuid);
    snapshot._isSelected = _isSelected;
    snapshot._isCollapsed = _isCollapsed;
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as FileHierarchyEntry;
    name.restoreWith(entry.name);
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    updateOrReplaceWith(entry.toList(), (obj) => (obj as HierarchyEntry).clone());
  }
}

class ExtractableHierarchyEntry extends FileHierarchyEntry {
  final String extractedPath;

  ExtractableHierarchyEntry(StringProp name, String filePath, this.extractedPath, bool isCollapsible, bool isOpenable)
    : super(name, filePath, isCollapsible, isOpenable);
  
  @override
  Undoable takeSnapshot() {
    var snapshot = ExtractableHierarchyEntry(name.takeSnapshot() as StringProp, this.path, extractedPath, isCollapsible, isOpenable);
    snapshot.overrideUuidForUndoable(uuid);
    snapshot._isSelected = _isSelected;
    snapshot._isCollapsed = _isCollapsed;
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as ExtractableHierarchyEntry;
    name.restoreWith(entry.name);
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    updateOrReplaceWith(entry.toList(), (obj) => (obj as HierarchyEntry).clone());
  }
}

class DatHierarchyEntry extends ExtractableHierarchyEntry {
  DatHierarchyEntry(StringProp name, String path, String extractedPath)
    : super(name, path, extractedPath, true, false);

  @override
  HierarchyEntry clone() {
    var entry = DatHierarchyEntry(name.takeSnapshot() as StringProp, this.path, extractedPath);
    entry._isSelected = _isSelected;
    entry._isCollapsed = _isCollapsed;
    entry.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return entry;
  }
}

class PakHierarchyEntry extends ExtractableHierarchyEntry {
  final Map<int, HapGroupHierarchyEntry> _flatGroups = {};

  PakHierarchyEntry(StringProp name, String path, String extractedPath)
    : super(name, path, extractedPath, true, false);

  Future<void> readGroups(String groupsXmlPath, HierarchyEntry? parent) async {
    var groupsFile = File(groupsXmlPath);
    if (!await groupsFile.exists()) {
      var yaxPath = groupsXmlPath.replaceAll(".xml", ".yax");
      if (await File(yaxPath).exists())
        await yaxFileToXmlFile(yaxPath);
      else
        return;
    }
    var groupsFileData = areasManager.openFileAsHidden(groupsXmlPath) as XmlFileData;
    await groupsFileData.load();
    // var groupsXmlContents = await groupsFile.readAsString();
    // var xmlDoc = XmlDocument.parse(groupsXmlContents);
    // var xmlRoot = xmlDoc.firstElementChild!;
    var xmlRoot = groupsFileData.root!;
    var groups = xmlRoot.getAll("group");
    
    for (var group in groups) {
      var groupId = (group.get("id")!.value as HexProp).value;
      var parentId = (group.get("parent")!.value as HexProp).value;
      var groupName = group.get("name")!.value as StringProp;
      HapGroupHierarchyEntry groupEntry = HapGroupHierarchyEntry(groupName, group);
      
      _findAndAddChildPak(parent, groupId, groupEntry);

      _flatGroups[groupId] = groupEntry;
      if (_flatGroups.containsKey(parentId))
        _flatGroups[parentId]!.add(groupEntry);
      else
        add(groupEntry);
    }
  }

  void _findAndAddChildPak(HierarchyEntry? parent, int groupId, HierarchyEntry groupEntry) {
    if (parent == null)
      return;
    if (parent is! DatHierarchyEntry)
      return;
    
    var childPak = parent.findRecWhere((entry) {
      if (entry is! PakHierarchyEntry)
        return false;
      var pakGroupId = _pakGroupIdMatcher.firstMatch(entry.name.value);
      if (pakGroupId == null)
        return false;
      return int.parse(pakGroupId.group(1)!, radix: 16) == groupId;
    });
    if (childPak != null) {
      openHierarchyManager.parentOf(childPak).remove(childPak);
      groupEntry.add(childPak);
    }
  }

  @override
  void add(HierarchyEntry child) {
    if (child is! XmlScriptHierarchyEntry) {
      super.add(child);
      return;
    }
    int parentGroup = child.groupId;
    if (_flatGroups.containsKey(parentGroup))
      _flatGroups[parentGroup]!.add(child);
    else
      super.add(child);
  }
  
  @override
  Undoable takeSnapshot() {
    var snapshot = PakHierarchyEntry(name.takeSnapshot() as StringProp, this.path, extractedPath);
    snapshot.overrideUuidForUndoable(uuid);
    snapshot._isSelected = _isSelected;
    snapshot._isCollapsed = _isCollapsed;
    snapshot._flatGroups.addAll(_flatGroups);
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as PakHierarchyEntry;
    name.restoreWith(entry.name);
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    updateOrReplaceWith(entry.toList(), (obj) => (obj as HierarchyEntry).clone());
  }
}

class GroupToken with Undoable {
  final HexProp code;
  final HexProp id;
  GroupToken(this.code, this.id);

  @override
  Undoable takeSnapshot() {
    return GroupToken(code.takeSnapshot() as HexProp, id.takeSnapshot() as HexProp);
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as GroupToken;
    code.restoreWith(entry.code);
    id.restoreWith(entry.id);
  }
}

class HapGroupHierarchyEntry extends FileHierarchyEntry {
  final int id;
  final XmlProp prop;
  
  HapGroupHierarchyEntry(StringProp name, this.prop)
    : id = (prop.get("id")!.value as HexProp).value,
    super(name, path.dirname(prop.file?.path ?? ""), true, false);
  
  HapGroupHierarchyEntry addChild({ String name = "New Group" }) {
    var newGroupProp = XmlProp.fromXml(
      makeXmlElement(name: "group", children: [
        makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
        makeXmlElement(name: "name", text: name),
        makeXmlElement(name: "parent", text: "0x${id.toRadixString(16)}"),
      ]),
      file: prop.file,
      parentTags: prop.parentTags
    );
    var xmlRoot = (prop.file! as XmlFileData).root!;
    var insertIndex = xmlRoot.length;
    var childGroups = xmlRoot.where((group) => group.tagName == "group" && (group.get("parent")?.value as HexProp).value == id);
    if (childGroups.isNotEmpty) {
      var lastChild = childGroups.last;
      var lastIndex = xmlRoot.indexOf(lastChild);
      insertIndex = lastIndex + 1;
    }
    xmlRoot.insert(insertIndex, newGroupProp);

    var ownInsertIndex = 0;
    var ownChildGroups = whereType<HapGroupHierarchyEntry>();
    if (ownChildGroups.isNotEmpty) {
      var lastChild = ownChildGroups.last;
      var lastIndex = indexOf(lastChild);
      ownInsertIndex = lastIndex + 1;
    }

    var countProp = xmlRoot.get("count")!.value as NumberProp;
    countProp.value += 1;

    var newGroup = HapGroupHierarchyEntry(newGroupProp.get("name")!.value as StringProp, newGroupProp);
    insert(ownInsertIndex, newGroup);

    return newGroup;
  }

  void removeSelf() {
    var xmlRoot = (prop.file! as XmlFileData).root!;
    var index = xmlRoot.indexOf(prop);
    xmlRoot.removeAt(index);

    var countProp = xmlRoot.get("count")!.value as NumberProp;
    countProp.value -= 1;

    openHierarchyManager.removeAny(this);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = HapGroupHierarchyEntry(name.takeSnapshot() as StringProp, prop.takeSnapshot() as XmlProp);
    snapshot.overrideUuidForUndoable(uuid);
    snapshot._isSelected = _isSelected;
    snapshot._isCollapsed = _isCollapsed;
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as HapGroupHierarchyEntry;
    name.restoreWith(entry.name);
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    prop.restoreWith(entry.prop);
    updateOrReplaceWith(entry.toList(), (obj) => (obj as HierarchyEntry).clone());
  }
}

class XmlScriptHierarchyEntry extends FileHierarchyEntry {
  int groupId = -1;
  bool _hasReadMeta = false;
  String _hapName = "";

  XmlScriptHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true)
  {
    this.name.transform = (str) {
      if (_hapName.isNotEmpty)
        return "$str - ${tryToTranslate(_hapName)}";
      return str;
    };
  }
  
  bool get hasReadMeta => _hasReadMeta;

  String get hapName => _hapName;

  set hapName(String value) {
    if (value == _hapName) return;
    _hapName = value;
    notifyListeners();
  }

  Future<void> readMeta() async {
    if (_hasReadMeta) return;

    var scriptFile = File(this.path);
    var scriptContents = await scriptFile.readAsString();
    var xmlRoot = XmlDocument.parse(scriptContents).firstElementChild!;
    var group = xmlRoot.findElements("group");
    if (group.isNotEmpty && group.first.text.startsWith("0x"))
      groupId = int.parse(group.first.text);
    
    var name = xmlRoot.findElements("name");
    if (name.isNotEmpty)
      _hapName = name.first.text;
    
    _hasReadMeta = true;
  }
  
  @override
  Undoable takeSnapshot() {
    var snapshot = XmlScriptHierarchyEntry(name.takeSnapshot() as StringProp, this.path);
    snapshot.overrideUuidForUndoable(uuid);
    snapshot._isSelected = _isSelected;
    snapshot._isCollapsed = _isCollapsed;
    snapshot._hasReadMeta = _hasReadMeta;
    snapshot._hapName = _hapName;
    snapshot.groupId = groupId;
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as XmlScriptHierarchyEntry;
    name.restoreWith(entry.name);
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    _hasReadMeta = entry._hasReadMeta;
    hapName = entry.hapName;
    updateOrReplaceWith(entry.toList(), (obj) => (obj as HierarchyEntry).clone());
  }
}

class RubyScriptHierarchyEntry extends FileHierarchyEntry {
  RubyScriptHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
}

class TmdHierarchyEntry extends FileHierarchyEntry {
  TmdHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
}

class SmdHierarchyEntry extends FileHierarchyEntry {
  SmdHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
}

class McdHierarchyEntry extends FileHierarchyEntry {
  McdHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
}

class OpenHierarchyManager extends NestedNotifier<HierarchyEntry> with Undoable {
  HierarchyEntry? _selectedEntry;

  OpenHierarchyManager() : super([]);

  NestedNotifier parentOf(HierarchyEntry entry) {
    return findRecWhere((e) => e.contains(entry)) ?? this;
  }

  Future<HierarchyEntry> openFile(String filePath, { HierarchyEntry? parent }) async {
    isLoadingStatus.pushIsLoading();

    HierarchyEntry entry;
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
    const supportedFileEndings = { ".pak", "_scp.bin", ".tmd", ".smd", ".mcd" };
    for (var file in datFilePaths) {
      if (supportedFileEndings.every((ending) => !file.endsWith(ending)))
        continue;
      int existingEntryI = existingEntries.indexWhere((entry) => (entry as FileHierarchyEntry).path == file);
      if (existingEntryI != -1) {
        datEntry.add(existingEntries[existingEntryI]);
        continue;
      }
      if (file.endsWith(".pak"))
        futures.add(openPak(file, parent: datEntry));
      else if (file.endsWith("_scp.bin"))
        futures.add(openBinMrbScript(file, parent: datEntry));
      else if (file.endsWith(".tmd"))
        openGenericFile<TmdHierarchyEntry>(file, datEntry, (n, p) => TmdHierarchyEntry(n, p));
      else if (file.endsWith(".smd"))
        openGenericFile<SmdHierarchyEntry>(file, datEntry, (n ,p) => SmdHierarchyEntry(n, p));
      else if (file.endsWith(".mcd"))
        openGenericFile<McdHierarchyEntry>(file, datEntry, (n ,p) => McdHierarchyEntry(n, p));
      else
        throw FileSystemException("Unsupported file type: $file");
    }

    await Future.wait(futures);

    return datEntry;
  }

  Future<HierarchyEntry> openExtractedDat(String datDirPath, { HierarchyEntry? parent }) {
    var srcDatDir = path.dirname(path.dirname(datDirPath));
    var srcDatPath = path.join(srcDatDir, path.basename(datDirPath));
    return openDat(srcDatPath, parent: parent);
  }
  
  HapGroupHierarchyEntry? findPakParentGroup(String fileName) {
    var match = _pakGroupIdMatcher.firstMatch(fileName);
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

  HierarchyEntry openGenericFile<T extends FileHierarchyEntry>(String filePath, HierarchyEntry? parent, HierarchyEntry Function(StringProp n, String p) make) {
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
    // TODO xml to yax
    
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
    snapshot.replaceWith(map((entry) => entry.clone()).toList());
    snapshot._selectedEntry = _selectedEntry != null ? _selectedEntry?.takeSnapshot() as HierarchyEntry : null;
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as OpenHierarchyManager;
    updateOrReplaceWith(entry.toList(), (obj) => (obj as HierarchyEntry).clone());
    if (entry.selectedEntry != null)
      selectedEntry = findRecWhere((e) => entry.selectedEntry!.uuid == e.uuid);
    else
      selectedEntry = null;
  }
}

final openHierarchyManager = OpenHierarchyManager();
