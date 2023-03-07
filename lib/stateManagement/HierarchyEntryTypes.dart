
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../fileTypeUtils/audio/audioModPacker.dart';
import '../fileTypeUtils/audio/audioModsChangesUndo.dart';
import '../fileTypeUtils/audio/modInstaller.dart';
import '../fileTypeUtils/audio/waiExtractor.dart';
import '../fileTypeUtils/audio/wemToWavConverter.dart';
import '../fileTypeUtils/bxm/bxmReader.dart';
import '../fileTypeUtils/bxm/bxmWriter.dart';
import '../fileTypeUtils/dat/datRepacker.dart';
import '../fileTypeUtils/pak/pakRepacker.dart';
import '../fileTypeUtils/ruby/pythonRuby.dart';
import '../fileTypeUtils/yax/xmlToYax.dart';
import '../fileTypeUtils/yax/yaxToXml.dart';
import '../main.dart';
import '../utils/assetDirFinder.dart';
import '../utils/utils.dart';
import '../widgets/misc/confirmCancelDialog.dart';
import '../widgets/misc/confirmDialog.dart';
import 'FileHierarchy.dart';
import 'Property.dart';
import 'events/searchPanelEvents.dart';
import 'hasUuid.dart';
import 'openFileTypes.dart';
import 'openFilesManager.dart';
import 'preferencesData.dart';
import 'undoable.dart';
import 'listNotifier.dart';
import 'xmlProps/xmlProp.dart';

final pakGroupIdMatcher = RegExp(r"^\w+_([a-f0-9]+)_grp\.pak$", caseSensitive: false);

class HierarchyEntryAction {
  final String name;
  final IconData? icon;
  final double iconScale;
  final void Function() action;

  const HierarchyEntryAction({ required this.name, this.icon, this.iconScale = 1.0, required this.action });
}

abstract class HierarchyEntry extends ListNotifier<HierarchyEntry> with Undoable {
  OptionalFileInfo? optionalFileInfo;
  StringProp name;
  final bool isSelectable;
  bool _isSelected = false;
  bool get isSelected => _isSelected;
  final bool isCollapsible;
  bool _isCollapsed = false;
  final bool isOpenable;
  bool isVisibleWithSearch = true;

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

  List<HierarchyEntryAction> getActions() {
    return [];
  }

  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      if (isNotEmpty) ...[
        HierarchyEntryAction(
          name: "Collapse all",
          icon: Icons.unfold_less,
          iconScale: 1.1,
          action: () => setCollapsedRecursive(true)
        ),
        HierarchyEntryAction(
          name: "Expand all",
          icon: Icons.unfold_more,
          iconScale: 1.1,
          action: () => setCollapsedRecursive(false)
        ),
      ],
      if (openHierarchyManager.contains(this)) ...[
        HierarchyEntryAction(
          name: "Close",
          icon: Icons.close,
          iconScale: 0.85,
          action: () => openHierarchyManager.remove(this),
        ),
        HierarchyEntryAction(
          name: "Close All",
          icon: Icons.close,
          action: () => openHierarchyManager.clear(),
        ),
      ],
    ];
  }
  
  void setCollapsedRecursive(bool value, [bool setSelf = false]) {
    if (setSelf)
      isCollapsed = value;
    for (var child in this) {
      child.setCollapsedRecursive(value, true);
    }
  }

  // 3 methods for checking if is visible with search
  // 3 steps:
  //   1. set isVisibleWithSearch to false for all entries
  //   2. for each entry, check and store if it is visible with search
  //   3. propagate visibility to parents and children (if an entry is visible, all its parents and children are visible)
  void setIsVisibleWithSearchRecursive(bool value) {
    isVisibleWithSearch = value;
    for (var child in this) {
      child.setIsVisibleWithSearchRecursive(value);
    }
  }
  void computeIsVisibleWithSearchFilter() {
    var search = openHierarchySearch.value.toLowerCase();
    if (search.isEmpty)
      isVisibleWithSearch = true;
    else if (name.toString().toLowerCase().contains(search))
      isVisibleWithSearch = true;
    else
      isVisibleWithSearch = false;
    for (var child in this) {
      child.computeIsVisibleWithSearchFilter();
    }
  }
  void propagateVisibility() {
    if (!isVisibleWithSearch) {
      for (var child in this)
        child.propagateVisibility();
      return;
    }
    
    var parent = openHierarchyManager.parentOf(this);
    while (parent is HierarchyEntry) {
      parent.isVisibleWithSearch = true;
      parent = openHierarchyManager.parentOf(parent);
    }
    setIsVisibleWithSearchRecursive(true);
  }
}

abstract class FileHierarchyEntry extends HierarchyEntry {
  final String path;
  bool supportsVsCodeEditing = false;

  FileHierarchyEntry(StringProp name, this.path, bool isCollapsible, bool isOpenable)
    : super(name, true, isCollapsible, isOpenable);

  @override
  Future<void> onOpen() async {
    if (await _tryOpenInVsCode())
      return;
    
    areasManager.openFile(path, secondaryName: null, optionalInfo: optionalFileInfo);
  }

  String get vsCodeEditingPath => path;

  Future<bool> _tryOpenInVsCode() async {
    var prefs = PreferencesData();
    if (supportsVsCodeEditing && prefs.preferVsCode?.value == true && await hasVsCode()) {
      openInVsCode(vsCodeEditingPath);
      return true;
    }
    return false;
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      HierarchyEntryAction(
        name: "Show in Explorer",
        icon: Icons.open_in_new,
        action: () => revealFileInExplorer(path)
      ),
      ...super.getContextMenuActions(),
    ];
  }
}

abstract class GenericFileHierarchyEntry extends FileHierarchyEntry {
  GenericFileHierarchyEntry(super.name, super.path, super.isCollapsible, super.isOpenable);
  
  HierarchyEntry clone();

  @override
  Undoable takeSnapshot() {
    var entry = clone();
    entry.overrideUuid(uuid);
    entry._isSelected = _isSelected;
    entry._isCollapsed = _isCollapsed;
    entry.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return entry;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as HierarchyEntry;
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    replaceWith(entry.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
  }
}

abstract class ExtractableHierarchyEntry extends FileHierarchyEntry {
  final String extractedPath;

  ExtractableHierarchyEntry(StringProp name, String filePath, this.extractedPath, bool isCollapsible, bool isOpenable)
    : super(name, filePath, isCollapsible, isOpenable);

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      HierarchyEntryAction(
        name: "Set search path",
        icon: Icons.search,
        action: () => searchPathChangeStream.add(extractedPath)
      ),
      ...super.getContextMenuActions(),
    ];
  }
}

class DatHierarchyEntry extends ExtractableHierarchyEntry {
  DatHierarchyEntry(StringProp name, String path, String extractedPath)
    : super(name, path, extractedPath, true, false);

  @override
  Undoable takeSnapshot() {
    var entry = DatHierarchyEntry(name.takeSnapshot() as StringProp, path, extractedPath);
    entry.overrideUuid(uuid);
    entry._isSelected = _isSelected;
    entry._isCollapsed = _isCollapsed;
    entry.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return entry;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as DatHierarchyEntry;
    name.restoreWith(entry.name);
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    replaceWith(entry.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
  }

  Future<void> addNewRubyScript() async {
    if (await confirmDialog(getGlobalContext(), title: "Add new Ruby Script?") != true)
      return;
    var scriptGroup = firstWhere(
      (entry) => entry is RubyScriptGroupHierarchyEntry,
      orElse: () => RubyScriptGroupHierarchyEntry()
    ) as RubyScriptGroupHierarchyEntry;
    scriptGroup.name.value = "Ruby Scripts (${scriptGroup.length + 1})";
    if (!contains(scriptGroup))
      add(scriptGroup);
    await scriptGroup.addNewRubyScript(path, extractedPath);
  }

  Future<void> repackDatAction() async {
    var prefs = PreferencesData();
    if (prefs.dataExportPath?.value == null) {
      showToast("No export path set; go to Settings to set an export path");
      return;
    }
    var datBaseName = basename(extractedPath);
    var exportPath = join(prefs.dataExportPath!.value, getDatFolder(datBaseName), datBaseName);
    await repackDat(extractedPath, exportPath);
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Repack DAT",
        icon: Icons.file_upload,
        action: repackDatAction,
      ),
      HierarchyEntryAction(
        name: "Add new Ruby script",
        icon: Icons.code,
        action: () => addNewRubyScript(),
      ),
      ...super.getActions(),
    ];
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions()
    ];
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
    var groupsFileData = areasManager.openFileAsHidden(groupsXmlPath, optionalInfo: optionalFileInfo) as XmlFileData;
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
      var pakGroupId = pakGroupIdMatcher.firstMatch(entry.name.value);
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
    var snapshot = PakHierarchyEntry(name.takeSnapshot() as StringProp, path, extractedPath);
    snapshot.overrideUuid(uuid);
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
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Repack PAK",
        icon: Icons.file_upload,
        action: () => repackPak(extractedPath),
      ),
      ...super.getActions(),
    ];
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions()
    ];
  }
}

class GroupToken with HasUuid, Undoable {
  final HexProp code;
  final HexProp id;
  GroupToken(this.code, this.id);

  @override
  Undoable takeSnapshot() {
    var snapshot = GroupToken(code.takeSnapshot() as HexProp, id.takeSnapshot() as HexProp);
    snapshot.overrideUuid(uuid);
    return snapshot;
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
    super(name, dirname(areasManager.fromId(prop.file)?.path ?? ""), true, false);
  
  Future<void> addChild({ String name = "New Group" }) async {
    if (await confirmOrCancelDialog(getGlobalContext(), title: "Add new group?") != true)
      return; 
    var newGroupProp = XmlProp.fromXml(
      makeXmlElement(name: "group", children: [
        makeXmlElement(name: "id", text: "0x${randomId().toRadixString(16)}"),
        makeXmlElement(name: "name", text: name),
        makeXmlElement(name: "parent", text: "0x${id.toRadixString(16)}"),
      ]),
      file: prop.file,
      parentTags: prop.parentTags
    );
    var file = areasManager.fromId(prop.file)! as XmlFileData;
    var xmlRoot = file.root!;
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

    return;
  }

  void removeSelf() {
    var file = areasManager.fromId(prop.file)! as XmlFileData;
    var xmlRoot = file.root!;
    var index = xmlRoot.indexOf(prop);
    xmlRoot.removeAt(index);

    var countProp = xmlRoot.get("count")!.value as NumberProp;
    countProp.value -= 1;

    openHierarchyManager.removeAny(this);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = HapGroupHierarchyEntry(name.takeSnapshot() as StringProp, prop.takeSnapshot() as XmlProp);
    snapshot.overrideUuid(uuid);
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
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "New Script",
        icon: Icons.description,
        action: () => openHierarchyManager.addScript(this, parentPath: path),
      ),
      HierarchyEntryAction(
        name: "New Group",
        icon: Icons.workspaces,
        action: addChild,
      ),
      if (isEmpty)
        HierarchyEntryAction(
          name: "Remove",
          icon: Icons.remove,
          action: removeSelf,
        ),
      ...super.getActions()
    ];
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions()
    ];
  }
}

class XmlScriptHierarchyEntry extends FileHierarchyEntry {
  int groupId = -1;
  bool _hasReadMeta = false;
  String _hapName = "";

  XmlScriptHierarchyEntry(StringProp name, String path, { bool? preferVsCode })
    : super(name, path, false, true)
  {
    this.name.transform = (str) {
      if (_hapName.isNotEmpty)
        return "$str - ${tryToTranslate(_hapName)}";
      return str;
    };
    supportsVsCodeEditing = preferVsCode ?? basename(path) == "0.xml";
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

    var scriptFile = File(path);
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
  Future<void> onOpen() async {
    if (await _tryOpenInVsCode()) {
      openInVsCode(vsCodeEditingPath);
      return;
    }

    String? secondaryName = tryToTranslate(hapName);
    areasManager.openFile(path, secondaryName: secondaryName, optionalInfo: optionalFileInfo);
  }
  
  @override
  Undoable takeSnapshot() {
    var snapshot = XmlScriptHierarchyEntry(name.takeSnapshot() as StringProp, path);
    snapshot.overrideUuid(uuid);
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
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      HierarchyEntryAction(
        name: "Export YAX",
        icon: Icons.file_upload,
        action: () => xmlFileToYaxFile(path),
      ),
      HierarchyEntryAction(
        name: "Unlink",
        icon: Icons.close,
        action: () => openHierarchyManager.unlinkScript(this),
      ),
      HierarchyEntryAction(
        name: "Delete",
        icon: Icons.delete,
        action: () => openHierarchyManager.deleteScript(this),
      ),
      ...super.getContextMenuActions()
    ];
  }
}

class RubyScriptGroupHierarchyEntry extends HierarchyEntry {
  RubyScriptGroupHierarchyEntry()
    : super(StringProp("Ruby Scripts"), false, true, false);
  
  @override
  Undoable takeSnapshot() {
    var snapshot = RubyScriptGroupHierarchyEntry();
    snapshot.overrideUuid(uuid);
    snapshot._isSelected = _isSelected;
    snapshot._isCollapsed = _isCollapsed;
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as RubyScriptGroupHierarchyEntry;
    _isCollapsed = entry._isCollapsed;
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
  }
  
  Future<void> addNewRubyScript(String datPath, String datExtractedPath) async {
    var datInfoPath = join(datExtractedPath, "dat_info.json");
    Map datInfo;
    if (await File(datInfoPath).exists()) {
      datInfo = jsonDecode(await File(datInfoPath).readAsString());
    } else {
      datInfo = {
        "version": 1,
        "files": (await getDatFileList(datExtractedPath))
          .map((path) => basename(path))
          .toList(),
        "basename": basenameWithoutExtension(datPath),
        "ext": "dat",
      };
    }

    var newScriptBin = "${basenameWithoutExtension(datPath)}_${randomId().toRadixString(16)}_scp.bin";
    var newScriptRb = "$newScriptBin.rb";
    var datFiles = (datInfo["files"] as List).cast<String>();
    datFiles.add(newScriptBin);
    datFiles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    datInfo["files"] = datFiles;

    var newScriptPath = join(datExtractedPath, newScriptRb);
    const scriptTemplate = """
proxy = ScriptProxy.new()
class << proxy
	# DIALOGUE

	# EVENT CALLBACKS
  
	# EVENT TRIGGERS
	def update()
	end
end

Fiber.new() { proxy.update() }
""";
    await File(newScriptPath).writeAsString(scriptTemplate);
    await rubyFileToBin(newScriptPath);
    await File(datInfoPath).writeAsString(const JsonEncoder.withIndent("\t").convert(datInfo));

    var newScriptEntry = RubyScriptHierarchyEntry(StringProp(newScriptRb), newScriptPath);
    add(newScriptEntry);
    newScriptEntry.onOpen();
  }
}

class RubyScriptHierarchyEntry extends GenericFileHierarchyEntry {
  RubyScriptHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true) {
    supportsVsCodeEditing = true;
  }
  
  @override
  HierarchyEntry clone() {
    return RubyScriptHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Compile to .bin",
        icon: Icons.file_upload,
        action: () async {
          var success = await rubyFileToBin(path);
          if (!success)
            return;
          var datPath = dirname(path);
          if (!strEndsWithDat(datPath))
            return;
          var parent = openHierarchyManager.parentOf(this);
          if (parent is! DatHierarchyEntry) {
            if (parent is HierarchyEntry)
              parent = openHierarchyManager.parentOf(parent);
            else
              return;
          }
          if (parent is! DatHierarchyEntry)
            return;
          await parent.repackDatAction();
        },
      ),
    ];
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions(),
    ];
  }
}

class TmdHierarchyEntry extends GenericFileHierarchyEntry {
  TmdHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
  
  @override
  HierarchyEntry clone() {
    return TmdHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}

class SmdHierarchyEntry extends GenericFileHierarchyEntry {
  SmdHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
  
  @override
  HierarchyEntry clone() {
    return SmdHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}

class McdHierarchyEntry extends GenericFileHierarchyEntry {
  McdHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
  
  @override
  HierarchyEntry clone() {
    return McdHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}

class FtbHierarchyEntry extends GenericFileHierarchyEntry {
  FtbHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
  
  @override
  HierarchyEntry clone() {
    return FtbHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}

class BxmHierarchyEntry extends GenericFileHierarchyEntry {
  final String xmlPath;
  
  BxmHierarchyEntry(StringProp name, String path)
    : xmlPath = "$path.xml",
    super(name, path, false, true) {
    supportsVsCodeEditing = true;
  }
  
  @override
  HierarchyEntry clone() {
    return BxmHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }

  @override
  Future<void> onOpen() async {
    if (await _tryOpenInVsCode()) {
      openInVsCode(vsCodeEditingPath);
      return;
    }

    showToast("Can't open BXM files. Right click to convert");
  }
  
  Future<void> toXml() async {
    await convertBxmFileToXml(path, xmlPath);
    showToast("Saved to ${basename(xmlPath)}");
  }

  Future<void> toBxm() async {
    await convertXmlToBxmFile(xmlPath, path);
    showToast("Updated ${basename(path)}");
  }

  @override
  String get vsCodeEditingPath => xmlPath;

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Convert to XML",
        icon: Icons.file_download,
        action: toXml,
      ),
      HierarchyEntryAction(
        name: "Convert to BXM",
        icon: Icons.file_upload,
        action: toBxm,
      ),
      ...super.getActions(),
    ];
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions(),
    ];
  }
}

class WaiHierarchyEntry extends ExtractableHierarchyEntry {
  OpenFileId waiDataId;
  List<WaiChild> structure = [];

  WaiHierarchyEntry(StringProp name, String path, String extractedPath, this.waiDataId)
    : super(name, path, extractedPath, true, false);

  @override
  Undoable takeSnapshot() {
    var snapshot =  WaiHierarchyEntry(name.takeSnapshot() as StringProp, path, extractedPath, waiDataId);
    snapshot.overrideUuid(uuid);
    snapshot._isSelected = _isSelected;
    snapshot._isCollapsed = _isCollapsed;
    snapshot.structure = structure;
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as WaiHierarchyEntry;
    name.restoreWith(entry.name);
    _isSelected = entry._isSelected;
    _isCollapsed = entry._isCollapsed;
    replaceWith(entry.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Package Mod",
        icon: Icons.file_upload,
        action: () => packAudioMod(path),
      ),
      HierarchyEntryAction(
        name: "Install Packaged Mod",
        icon: Icons.add,
        action: () => installMod(path),
      ),
      HierarchyEntryAction(
        name: "Revert all changes",
        icon: Icons.undo,
        action: () => revertAllAudioMods(path),
      ),
      ...super.getActions(),
    ];
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions(),
    ];
  }
}

class WaiFolderHierarchyEntry extends GenericFileHierarchyEntry {
  final String bgmBnkPath;

  WaiFolderHierarchyEntry(StringProp name, String path, List<WaiChild> children)
    : bgmBnkPath = join(dirname(path), "bgm", "BGM.bnk"),
      super(name, path, true, false) {
    _isCollapsed = true;
    addAll(children.map((child) => makeWaiChildEntry(child, bgmBnkPath)));
  }
  WaiFolderHierarchyEntry.clone(WaiFolderHierarchyEntry other)
    : bgmBnkPath = other.bgmBnkPath,
      super(other.name.takeSnapshot() as StringProp, other.path, true, false) {
    _isCollapsed = other._isCollapsed;
    addAll(other.map((entry) => (entry as GenericFileHierarchyEntry).clone()));
  }
  
  @override
  HierarchyEntry clone() {
    return WaiFolderHierarchyEntry.clone(this);
  }
}

class WspHierarchyEntry extends GenericFileHierarchyEntry {
  final List<WaiChild> _childWems;
  bool _hasLoadedChildren = false;
  final String bgmBnkPath;

  WspHierarchyEntry(StringProp name, String path, List<WaiChild> childWems, this.bgmBnkPath) :
    _childWems = childWems,
    super(name, path, true, false) {
    _isCollapsed = true;
    if (childWems.length < 200)
      addChildren();
  }
  
  @override
  set isCollapsed(bool value) {
    if (value == _isCollapsed)
      return;
    _isCollapsed = value;
    notifyListeners();

    if (!_isCollapsed && !_hasLoadedChildren && isEmpty)
      addChildren();
  }

  void addChildren() {
    _hasLoadedChildren = true;
    addAll(_childWems.map((child) => makeWaiChildEntry(child, bgmBnkPath)));
  }
  
  @override
  HierarchyEntry clone() {
    return WspHierarchyEntry(name.takeSnapshot() as StringProp, path, _childWems, bgmBnkPath);
  }

  Future<void> exportAsWav() async {
    var saveDir = await FilePicker.platform.getDirectoryPath();
    if (saveDir == null)
      return;
    var wspDir = join(saveDir, basename(path));
    await Directory(wspDir).create(recursive: true);
    await Future.wait(
      whereType<WemHierarchyEntry>()
      .map((e) => e.exportAsWav(
        wavPath:  join(wspDir, "${basenameWithoutExtension(e.path)}.wav"),
        displayToast: false,
      )),
    );
    showToast("Saved $length WEMs");
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Save all as WAV",
        icon: Icons.file_download,
        action: exportAsWav,
      ),
      ...super.getActions(),
    ];
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions(),
    ];
  }
}

class WemHierarchyEntry extends GenericFileHierarchyEntry {
  final int wemId;

  WemHierarchyEntry(StringProp name, String path, this.wemId, OptionalWemData? optionalWemData)
    : super(name, path, false, true) {
    optionalFileInfo = optionalWemData; 
  }
  
  @override
  HierarchyEntry clone() {
    return WemHierarchyEntry(name.takeSnapshot() as StringProp, path, wemId, optionalFileInfo as OptionalWemData?);
  }

  Future<void> exportAsWav({ String? wavPath, bool displayToast = true }) async {
    wavPath ??= await FilePicker.platform.saveFile(
      fileName: "${basenameWithoutExtension(path)}.wav",
      allowedExtensions: ["wav"],
      type: FileType.custom,
    );
    if (wavPath == null)
      return;
    await wemToWav(path, wavPath);
    if (displayToast)
      showToast("Saved as ${basename(wavPath)}");
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Save as WAV",
        icon: Icons.file_download,
        action: exportAsWav,
      ),
      ...super.getActions(),
    ];
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      ...getActions(),
      ...super.getContextMenuActions(),
    ];
  }
}

HierarchyEntry makeWaiChildEntry(WaiChild child, String bgmBnkPath) {
  HierarchyEntry entry;
  if (child is WaiChildDir)
    entry = WaiFolderHierarchyEntry(StringProp(child.name), child.path, child.children);
  else if (child is WaiChildWsp)
    entry = WspHierarchyEntry(StringProp(child.name), child.path, child.children, bgmBnkPath);
  else if (child is WaiChildWem)
    entry = WemHierarchyEntry(
      StringProp(child.name),
      child.path,
      child.wemId,
      OptionalWemData(bgmBnkPath, WemSource.wsp)
    );
  else
    throw Exception("Unknown WAI child type: ${child.runtimeType}");
  return entry;
}

class BnkHierarchyEntry extends GenericFileHierarchyEntry {
  final String extractedPath;
 
  BnkHierarchyEntry(StringProp name, String path, this.extractedPath)
    : super(name, path, true, false);
  
  @override
  HierarchyEntry clone() {
    return BnkHierarchyEntry(name.takeSnapshot() as StringProp, path, extractedPath);
  }
}

class SaveSlotDataHierarchyEntry extends GenericFileHierarchyEntry {
  SaveSlotDataHierarchyEntry(StringProp name, String path)
    : super(name, path, false, true);
  
  @override
  HierarchyEntry clone() {
    return SaveSlotDataHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }
}

class WtaHierarchyEntry extends GenericFileHierarchyEntry {
  final String wtpPath;

  WtaHierarchyEntry(StringProp name, String path, this.wtpPath)
    : super(name, path, false, true);
  
  @override
  HierarchyEntry clone() {
    return WtaHierarchyEntry(name.takeSnapshot() as StringProp, path, wtpPath);
  }
}
