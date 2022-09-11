import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:tuple/tuple.dart';
import 'package:xml/xml.dart';

import '../fileTypeUtils/dat/datExtractor.dart';
import '../utils.dart';
import 'Property.dart';
import 'nestedNotifier.dart';
import '../fileTypeUtils/pak/pakExtractor.dart';

class HierarchyEntry extends NestedNotifier<HierarchyEntry> {
  String _name;
  final IconData? icon;
  final bool isSelectable;
  bool _isSelected = false;
  final bool isCollapsible;
  bool _isCollapsed = false;
  final bool isOpenable;
  final int priority;

  HierarchyEntry(this._name, this.priority, this.isSelectable, this.isCollapsible, this.isOpenable, { this.icon })
    : super([]);

  String get name => _name;

  set name(String value) {
    _name = value;
    notifyListeners();
  }

  bool get isSelected => _isSelected;

  set isSelected(bool value) {
    _isSelected = value;
    notifyListeners();
  }

  bool get isCollapsed => _isCollapsed;

  set isCollapsed(bool value) {
    _isCollapsed = value;
    notifyListeners();
  }

  void onOpen() {
    print("Not implemented!");
  }
}

class FileHierarchyEntry extends HierarchyEntry {
  final String path;

  FileHierarchyEntry(String name, this.path, int priority, bool isCollapsible, bool isOpenable, { IconData? icon })
    : super(name, priority, true, isCollapsible, isOpenable, icon: icon);
}

class ExtractableHierarchyEntry extends FileHierarchyEntry {
  final String extractedPath;

  ExtractableHierarchyEntry(String name, String filePath, this.extractedPath, int priority, bool isCollapsible, bool isOpenable, { IconData? icon })
    : super(name, filePath, priority, isCollapsible, isOpenable, icon: icon);
}

class DatHierarchyEntry extends ExtractableHierarchyEntry {
  DatHierarchyEntry(String name, String path, String extractedPath)
    : super(name, path, extractedPath, 10, true, false, icon: Icons.folder);
}

class PakHierarchyEntry extends ExtractableHierarchyEntry {
  final Map<int, HapGroupHierarchyEntry> _flatGroups = {};

  PakHierarchyEntry(String name, String path, String extractedPath)
    : super(name, path, extractedPath, 7, true, false, icon: Icons.source);

  Future<void> readGroups(String groupsXmlPath) async {
    var groupsFile = File(groupsXmlPath);
    var groupsXmlContents = await groupsFile.readAsString();
    var xmlDoc = XmlDocument.parse(groupsXmlContents);
    var xmlRoot = xmlDoc.firstElementChild!;
    var groups = xmlRoot.childElements
      .where((element) => element.name.toString() == "group");
    
    for (var group in groups) {
      String groupIdStr = group.findElements("id").first.text;
      int groupId = int.parse(groupIdStr);
      String groupName = group.findElements("name").first.text;
      int parentId = int.parse(group.findElements("parent").first.text);
      HapGroupHierarchyEntry groupEntry = HapGroupHierarchyEntry(groupName, groupId);

      var tokens = group.findElements("tokens");
      if (tokens.isNotEmpty) {
        for (var token in tokens.first.findElements("value")) {
          var code = int.parse(token.findElements("code").first.text);
          var id = int.parse(token.findElements("id").first.text);
          groupEntry.tokens.add(Token(HexProp(code), HexProp(id)));
        }
      }
      
      _flatGroups[groupId] = groupEntry;
      if (_flatGroups.containsKey(parentId))
        _flatGroups[parentId]!.add(groupEntry);
      else
        add(groupEntry);
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
}

typedef Token = Tuple2<HexProp, HexProp>;
class HapGroupHierarchyEntry extends FileHierarchyEntry {
  final int id;
  final NestedNotifier<Token> tokens = NestedNotifier([]);
  
  HapGroupHierarchyEntry(String name, this.id)
    : super(name, "", 5, true, false, icon: Icons.workspaces) {
    tokens.addListener(notifyListeners);
  }

  @override
  void dispose() {
    tokens.removeListener(notifyListeners);
    super.dispose();
  }
  
  @override
  String get name => tryToTranslate(super.name);
}

class XmlScriptHierarchyEntry extends FileHierarchyEntry {
  int groupId = -1;
  bool _hasReadMeta = false;
  String _hapName = "";

  XmlScriptHierarchyEntry(String name, String path)
    : super(name, path, 2, false, true, icon: null);
  
  bool get hasReadMeta => _hasReadMeta;

  String get hapName => _hapName;

  set hapName(String value) {
    _hapName = value;
    notifyListeners();
  }

  @override
  String get name {
    if (_hapName.isNotEmpty)
      return "$_name - ${tryToTranslate(_hapName)}";
    return _name;
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
}

class OpenHierarchyManager extends NestedNotifier<HierarchyEntry> {
  HierarchyEntry? _selectedEntry;

  OpenHierarchyManager() : super([]);

  HierarchyEntry? findRecWhere(bool Function(HierarchyEntry) test, { Iterable<HierarchyEntry>? children }) {
    children ??= this;
    for (var child in children) {
      if (test(child))
        return child;
      var result = findRecWhere(test, children: child);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  List<HierarchyEntry> findAllRecWhere(bool Function(HierarchyEntry) test, { Iterable<HierarchyEntry>? children }) {
    children ??= this;
    var result = <HierarchyEntry>[];
    for (var child in children) {
      if (test(child))
        result.add(child);
      result.addAll(findAllRecWhere(test, children: child));
    }
    return result;
  }

  NestedNotifier parentOf(HierarchyEntry entry) {
    return findRecWhere((e) => e.contains(entry)) ?? this;
  }

  void openFile(String filePath, { HierarchyEntry? parent }) {
    if (filePath.endsWith(".dat")) {
      if (File(filePath).existsSync())
        openDat(filePath, parent: parent);
      else if (Directory(filePath).existsSync())
        openExtractedDat(filePath, parent: parent);
      else
        throw FileSystemException("File not found: $filePath");
    }
    else if (filePath.endsWith(".pak")) {
      if (File(filePath).existsSync())
        openPak(filePath, parent: parent);
      else if (Directory(filePath).existsSync())
        openExtractedPak(filePath, parent: parent);
      else
        throw FileSystemException("File not found: $filePath");
    }
    else if (filePath.endsWith(".xml")) {
      if (File(filePath).existsSync())
        openXmlScript(filePath, parent: parent);
      else
        throw FileSystemException("File not found: $filePath");
    }
    else
      throw FileSystemException("Unsupported file type: $filePath");
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
    var datEntry = DatHierarchyEntry(fileName, datPath, datExtractDir);
    if (parent != null)
      parent.add(datEntry);
    else
      add(datEntry);

    var existingEntries = findAllRecWhere((entry) => 
      entry is PakHierarchyEntry && entry.path.startsWith(datExtractDir));
    for (var entry in existingEntries)
      parentOf(entry).remove(entry);
    
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
      openPak(pakPath, parent: datEntry);
    }
  }

  void openExtractedDat(String datDirPath, { HierarchyEntry? parent }) {
    var srcDatDir = path.dirname(path.dirname(datDirPath));
    var srcDatPath = path.join(srcDatDir, path.basename(datDirPath));
    openDat(srcDatPath, parent: parent);
  }

  void openPak(String pakPath, { HierarchyEntry? parent }) async {
    if (findRecWhere((entry) => entry is PakHierarchyEntry && entry.path == pakPath) != null)
      return;

    var pakFolder = path.dirname(pakPath);
    var pakExtractDir = path.join(pakFolder, "pakExtracted", path.basename(pakPath));
    if (!Directory(pakExtractDir).existsSync()) {
      await extractPakFiles(pakPath, yaxToXml: true);
    }
    var pakEntry = PakHierarchyEntry(pakPath.split(Platform.pathSeparator).last, pakPath, pakExtractDir);
    if (parent != null)
      parent.add(pakEntry);
    else
      add(pakEntry);
    await pakEntry.readGroups(path.join(pakExtractDir, "0.xml"));

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

      var xmlEntry = XmlScriptHierarchyEntry(xmlFile, xmlFilePath);
      await xmlEntry.readMeta();
      pakEntry.add(xmlEntry);
    }
  }

  void openExtractedPak(String pakDirPath, { HierarchyEntry? parent }) {
    var srcPakDir = path.dirname(path.dirname(pakDirPath));
    var srcPakPath = path.join(srcPakDir, path.basename(pakDirPath));
    openPak(srcPakPath, parent: parent);
  }

  void openXmlScript(String xmlFilePath, { HierarchyEntry? parent }) {
    if (findRecWhere((entry) => entry is XmlScriptHierarchyEntry && entry.path == xmlFilePath) != null)
      return;
    var entry = XmlScriptHierarchyEntry(path.basename(xmlFilePath), xmlFilePath);
    if (parent != null)
      parent.add(entry);
    else
      add(entry);
  }

  void expandAll() {
    var stack = toList();
    while (stack.isNotEmpty) {
      var entry = stack.removeLast();
      if (entry.isCollapsible)
        entry.isCollapsed = false;
      for (var child in entry)
        stack.add(child);
    }
  }
  
  void collapseAll() {
    var stack = toList();
    while (stack.isNotEmpty) {
      var entry = stack.removeLast();
      if (entry.isCollapsible)
        entry.isCollapsed = true;
      for (var child in entry)
        stack.add(child);
    }
  }

  HierarchyEntry? get selectedEntry => _selectedEntry;

  set selectedEntry(HierarchyEntry? value) {
    _selectedEntry?.isSelected = false;
    assert(value == null || value.isSelectable);
    _selectedEntry = value;
    _selectedEntry?.isSelected = true;
    notifyListeners();
  }
}

final openHierarchyManager = OpenHierarchyManager();