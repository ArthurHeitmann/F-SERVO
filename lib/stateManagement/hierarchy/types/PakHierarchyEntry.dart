
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/pak/pakRepacker.dart';
import '../../../fileTypeUtils/yax/yaxToXml.dart';
import '../../../main.dart';
import '../../../utils/utils.dart';
import '../../../widgets/misc/confirmCancelDialog.dart';
import '../../Property.dart';
import '../../hasUuid.dart';
import '../../openFiles/openFilesManager.dart';
import '../../openFiles/types/xml/XmlFileData.dart';
import '../../openFiles/types/xml/xmlProps/xmlProp.dart';
import '../../undoable.dart';
import '../FileHierarchy.dart';
import '../HierarchyEntryTypes.dart';
import 'DatHierarchyEntry.dart';
import 'XmlScriptHierarchyEntry.dart';

final pakGroupIdMatcher = RegExp(r"^\w+_([a-f0-9]+)_grp\.pak$", caseSensitive: false);

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
    snapshot.isSelected.value = isSelected.value;
    snapshot.isCollapsed.value = isCollapsed.value;
    snapshot._flatGroups.addAll(_flatGroups);
    snapshot.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as PakHierarchyEntry;
    name.restoreWith(entry.name);
    isSelected.value = entry.isSelected.value;
    isCollapsed.value = entry.isCollapsed.value;
    updateOrReplaceWith(entry.children.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
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
    var ownChildGroups = children.whereType<HapGroupHierarchyEntry>();
    if (ownChildGroups.isNotEmpty) {
      var lastChild = ownChildGroups.last;
      var lastIndex = children.indexOf(lastChild);
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
    snapshot.isSelected.value = isSelected.value;
    snapshot.isCollapsed.value = isCollapsed.value;
    snapshot.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as HapGroupHierarchyEntry;
    name.restoreWith(entry.name);
    isSelected.value = entry.isSelected.value;
    isCollapsed.value = entry.isCollapsed.value;
    prop.restoreWith(entry.prop);
    updateOrReplaceWith(entry.children.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
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
      if (children.isEmpty)
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
