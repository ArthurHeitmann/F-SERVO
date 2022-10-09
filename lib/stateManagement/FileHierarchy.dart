import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import '../fileTypeUtils/dat/datExtractor.dart';
import '../fileTypeUtils/yax/yaxToXml.dart';
import '../utils.dart';
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
  final bool isCollapsible;
  bool _isCollapsed = false;
  final bool isOpenable;
  final int priority;

  HierarchyEntry(this.name, this.priority, this.isSelectable, this.isCollapsible, this.isOpenable)
    : super([]);

  bool get isSelected => _isSelected;

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
    var snapshot = HierarchyEntry(name.takeSnapshot() as StringProp, priority, isSelectable, isCollapsible, isOpenable);
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

  FileHierarchyEntry(StringProp name, this.path, int priority, bool isCollapsible, bool isOpenable)
    : super(name, priority, true, isCollapsible, isOpenable);
  
  @override
  Undoable takeSnapshot() {
    var snapshot = FileHierarchyEntry(name.takeSnapshot() as StringProp, path, priority, isCollapsible, isOpenable);
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

  ExtractableHierarchyEntry(StringProp name, String filePath, this.extractedPath, int priority, bool isCollapsible, bool isOpenable)
    : super(name, filePath, priority, isCollapsible, isOpenable);
  
  @override
  Undoable takeSnapshot() {
    var snapshot = ExtractableHierarchyEntry(name.takeSnapshot() as StringProp, this.path, extractedPath, priority, isCollapsible, isOpenable);
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
    : super(name, path, extractedPath, 10, true, false);

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
    : super(name, path, extractedPath, 7, true, false);

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
    super(name, "", 5, true, false);

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
    : super(name, path, 2, false, true)
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

class OpenHierarchyManager extends NestedNotifier<HierarchyEntry> with Undoable {
  HierarchyEntry? _selectedEntry;

  OpenHierarchyManager() : super([]);

  NestedNotifier parentOf(HierarchyEntry entry) {
    return findRecWhere((e) => e.contains(entry)) ?? this;
  }

  Future<void> openFile(String filePath, { HierarchyEntry? parent }) async {
    isLoadingStatus.pushIsLoading();

    try {
      if (filePath.endsWith(".dat")) {
        if (await File(filePath).exists())
          await openDat(filePath, parent: parent);
        else if (await Directory(filePath).exists())
          await openExtractedDat(filePath, parent: parent);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".pak")) {
        if (await File(filePath).exists())
          await openPak(filePath, parent: parent);
        else if (await Directory(filePath).exists())
          await openExtractedPak(filePath, parent: parent);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else if (filePath.endsWith(".xml")) {
        if (await File(filePath).exists())
          openXmlScript(filePath, parent: parent);
        else
          throw FileSystemException("File not found: $filePath");
      }
      else
        throw FileSystemException("Unsupported file type: $filePath");
      
      undoHistoryManager.onUndoableEvent();
    } finally {
      isLoadingStatus.popIsLoading();
    }
  }

  Future<void> openDat(String datPath, { HierarchyEntry? parent }) async {
    if (findRecWhere((entry) => entry is DatHierarchyEntry && entry.path == datPath) != null)
      return;

    var fileName = path.basename(datPath);
    var datFolder = path.dirname(datPath);
    var datExtractDir = path.join(datFolder, "nier2blender_extracted", fileName);
    if (!Directory(datExtractDir).existsSync()) {   // TODO: check if extracted folder actually contains all dat files
      await extractDatFiles(datPath, shouldExtractPakFiles: true);
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

    List<Future<void>> futures = [];
    // TODO: search based on dat metadata
    for (var file in Directory(datExtractDir).listSync()) {
      if (file is! File || !file.path.endsWith(".pak"))
        continue;
      var pakPath = file.path;
      int existingEntryI = existingEntries.indexWhere((entry) => (entry as FileHierarchyEntry).path == pakPath);
      if (existingEntryI != -1) {
        datEntry.add(existingEntries[existingEntryI]);
        continue;
      }
      futures.add(openPak(pakPath, parent: datEntry));
    }

    await Future.wait(futures);
  }

  Future<void> openExtractedDat(String datDirPath, { HierarchyEntry? parent }) {
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

  Future<void> openPak(String pakPath, { HierarchyEntry? parent }) async {
    if (findRecWhere((entry) => entry is PakHierarchyEntry && entry.path == pakPath) != null)
      return;

    var pakFolder = path.dirname(pakPath);
    var pakExtractDir = path.join(pakFolder, "pakExtracted", path.basename(pakPath));
    if (!Directory(pakExtractDir).existsSync()) {
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

    var pakInfoJsonPath = path.join(pakExtractDir, "pakInfo.json");
    var pakInfoJson = json.decode(File(pakInfoJsonPath).readAsStringSync());
    for (var yaxFile in pakInfoJson["files"]) {
      var xmlFile = yaxFile["name"].replaceAll(".yax", ".xml");
      var xmlFilePath = path.join(pakExtractDir, xmlFile);
      int existingEntryI = existingEntries.indexWhere((entry) => (entry as FileHierarchyEntry).path == xmlFilePath);
      if (existingEntryI != -1) {
        pakEntry.add(existingEntries[existingEntryI]);
        continue;
      }
      if (!File(xmlFilePath).existsSync()) {
        // TODO: display error message
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
  }

  Future<void> openExtractedPak(String pakDirPath, { HierarchyEntry? parent }) {
    var srcPakDir = path.dirname(path.dirname(pakDirPath));
    var srcPakPath = path.join(srcPakDir, path.basename(pakDirPath));
    return openPak(srcPakPath, parent: parent);
  }

  void openXmlScript(String xmlFilePath, { HierarchyEntry? parent }) {
    if (findRecWhere((entry) => entry is XmlScriptHierarchyEntry && entry.path == xmlFilePath) != null)
      return;
    var entry = XmlScriptHierarchyEntry(StringProp(path.basename(xmlFilePath)), xmlFilePath);
    if (parent != null)
      parent.add(entry);
    else
      add(entry);
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
