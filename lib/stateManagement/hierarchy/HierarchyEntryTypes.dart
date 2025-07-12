
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../fileSystem/FileSystem.dart';
import '../../main.dart';
import '../../utils/Disposable.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../../widgets/misc/confirmCancelDialog.dart';
import '../Property.dart';
import '../changesExporter.dart';
import '../events/searchPanelEvents.dart';
import '../events/statusInfo.dart';
import '../hasUuid.dart';
import '../listNotifier.dart';
import '../openFiles/openFileTypes.dart';
import '../openFiles/openFilesManager.dart';
import '../preferencesData.dart';
import 'FileHierarchy.dart';
import 'types/DatHierarchyEntry.dart';
import 'types/PakHierarchyEntry.dart';

class HierarchyEntryAction {
  final String name;
  final IconData? icon;
  final double iconScale;
  final void Function() action;

  const HierarchyEntryAction({ required this.name, this.icon, this.iconScale = 1.0, required this.action });
}

mixin HierarchyEntryBase implements Disposable {
  final ListNotifier<HierarchyEntry> _children = ValueListNotifier([], fileId: null);
  IterableNotifier<HierarchyEntry> get children => _children;

  void add(HierarchyEntry child) {
    _children.add(child);
  }

  void addAll(Iterable<HierarchyEntry> children) {
    _children.addAll(children);
  }

  void insert(int index, HierarchyEntry child) {
    _children.insert(index, child);
  }

  void remove(HierarchyEntry child, { bool dispose = false }) {
    _children.remove(child);
    if (dispose)
      child.dispose();
  }

  void clear() {
    _children.clear();
  }

  void sortChildren([int Function(HierarchyEntry, HierarchyEntry)? compare]) {
    _children.sort(compare ?? (a, b) => a.name.toString().compareTo(b.name.toString()));
  }

  HierarchyEntry? findRecWhere(bool Function(HierarchyEntry) test, { Iterable<HierarchyEntry>? children }) {
    children ??= this.children;
    for (var child in children) {
      if (test(child))
        return child;
      var result = findRecWhere(test, children: child.children);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  List<HierarchyEntry> findAllRecWhere(bool Function(HierarchyEntry) test, { Iterable<HierarchyEntry>? children }) {
    children ??= this.children;
    List<HierarchyEntry> result = [];
    for (var child in children) {
      if (test(child))
        result.add(child);
      result.addAll(findAllRecWhere(test, children: child.children));
    }
    return result;
  }

  int countAllRec() {
    int count = children.length;
    for (var child in children)
      count += child.countAllRec();
    return count;
  }

  (bool, int) hasOverXChildren(int threshold, [int count = 0]) {
    // alternative to countAllRec, that stops counting when it reaches x
    count += children.length;
    if (count >= threshold)
      return (true, count);
    for (var child in children) {
      var result = child.hasOverXChildren(threshold, count);
      if (result.$1)
        return result;
      count = result.$2;
    }
    return (false, count);
  }

  @override
  void dispose() {
    _children.dispose();
  }
}

abstract class HierarchyEntry with HasUuid, HierarchyEntryBase {
  OptionalFileInfo? optionalFileInfo;
  final StringProp name;
  final bool isSelectable;
  final ValueNotifier<bool> isSelected = ValueNotifier(false);
  final bool isCollapsible;
  final ValueNotifier<bool> isCollapsed = ValueNotifier(false);
  final bool isOpenable;
  final int priority;
  final ValueNotifier<bool> isDirty = ValueNotifier(false);
  final ValueNotifier<bool> hasSavedChanges = ValueNotifier(false);

  HierarchyEntry(this.name, this.isSelectable, this.isCollapsible, this.isOpenable, { this.priority = 0 }) {
    children.addListener(() => openHierarchyManager.filteredTreeIsDirty.value = true);
    isCollapsed.addListener(() => openHierarchyManager.collapsedTreeIsDirty.value = true);
  }

  @override
  void dispose() {
    super.dispose();
    try {
      name.dispose();
    } catch (e) {
      // fix for HapGroupHierarchyEntry, where the name is owned and disposed by an open file
      if (this is! HapGroupHierarchyEntry)
        rethrow;
    }
    isSelected.dispose();
    isCollapsed.dispose();
    isDirty.dispose();
    hasSavedChanges.dispose();
  }

  void onOpen() {
    print("Not implemented!");
  }

  List<HierarchyEntryAction> getActions() {
    return [];
  }

  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      if (children.isNotEmpty) ...[
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
      if (openHierarchyManager.children.contains(this)) ...[
        HierarchyEntryAction(
          name: "Close",
          icon: Icons.close,
          iconScale: 0.85,
          action: () => openHierarchyManager.remove(this, dispose: true),
        ),
        HierarchyEntryAction(
          name: "Close All",
          icon: Icons.close,
          action: () async {
            if (await confirmOrCancelDialog(getGlobalContext(), title: "Close All", body: "Are you sure you want to close all open files?") == true)
              openHierarchyManager.clear();
          },
        ),
      ],
    ];
  }
  
  void setCollapsedRecursive(bool value, [bool setSelf = false]) {
    if (setSelf)
      isCollapsed.value = value;
    for (var child in children) {
      child.setCollapsedRecursive(value, true);
    }
  }
}

abstract class FileHierarchyEntry extends HierarchyEntry {
  final String path;
  bool supportsVsCodeEditing = false;

  FileHierarchyEntry(StringProp name, this.path, bool isCollapsible, bool isOpenable, { super.priority = 1 })
    : super(name, true, isCollapsible, isOpenable);

  @override
  Future<void> onOpen() async {
    if (await tryOpenInVsCode())
      return;
    
    areasManager.openFile(path, secondaryName: null, optionalInfo: optionalFileInfo);
  }

  String get vsCodeEditingPath => path;

  Future<bool> tryOpenInVsCode() async {
    var prefs = PreferencesData();
    if (supportsVsCodeEditing && prefs.preferVsCode?.value == true && await hasVsCode()) {
      openInVsCode(vsCodeEditingPath);
      return true;
    }
    return false;
  }

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    var parent = openHierarchyManager.parentOf(this);
    var parentIsDat = parent is DatHierarchyEntry;
    return [
      if (isDesktop)
        HierarchyEntryAction(
          name: "Show in Explorer",
          icon: Icons.open_in_new,
          action: () => revealFileInExplorer(path)
        ),
      if (FS.i.isVirtual(path))
        HierarchyEntryAction(
          name: getDownloadText(),
          icon: Icons.download,
          action: () => downloadFile(path)
        ),
      if (parentIsDat)
        HierarchyEntryAction(
          name: "Remove from DAT",
          icon: Icons.delete,
          action: () => _removeSelfFromDat(parent)
        ),
      ...super.getContextMenuActions(),
    ];
  }

  void _removeSelfFromDat(DatHierarchyEntry parent) async {
    var datInfoPath = join(parent.extractedPath, "dat_info.json");
    if (!await FS.i.existsFile(datInfoPath)) {
      messageLog.add("File was not extracted with F-SERVO. Missing dat_info.json");
      return;
    }
    var datInfo = jsonDecode(await FS.i.readAsString(datInfoPath));

    var datFiles = (datInfo["files"] as List).cast<String>();
    var prevLength = datFiles.length;
    datFiles.removeWhere((file) => file.toLowerCase() == basename(path).toLowerCase());
    datInfo["files"] = datFiles;
    
    var removedFiles = datFiles.length - prevLength;
    if (removedFiles == 0) {
      messageLog.add("Failed to find ${name.value} in DAT");
      return;
    }
    print("removedFiles $removedFiles");

    var datName = basename(parent.path);
    if (await confirmOrCancelDialog(getGlobalContext(), title: "Removed ${name.value} from $datName?", yesText: "Remove") != true) {
      return;
    }

    await FS.i.writeAsString(datInfoPath, const JsonEncoder.withIndent("\t").convert(datInfo));

    parent.isDirty.value = true;
    changedDatFiles.add(parent.extractedPath);
    await processChangedFiles();

    parent.remove(this, dispose: true);
    
    messageLog.add("Removed ${name.value} from $datName");
  }
}

abstract class ExtractableHierarchyEntry extends FileHierarchyEntry {
  final String extractedPath;

  ExtractableHierarchyEntry(StringProp name, String filePath, this.extractedPath, bool isCollapsible, bool isOpenable, { super.priority = 1 })
    : super(name, filePath, isCollapsible, isOpenable);

  @override
  List<HierarchyEntryAction> getContextMenuActions() {
    return [
      if (!FS.i.useVirtualFs)
        HierarchyEntryAction(
          name: "Set search path",
          icon: Icons.search,
          action: () => searchPathChangeStream.add(extractedPath)
        ),
      ...super.getContextMenuActions(),
    ];
  }
}
