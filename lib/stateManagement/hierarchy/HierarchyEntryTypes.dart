
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/audio/audioModPacker.dart';
import '../../fileTypeUtils/audio/audioModsChangesUndo.dart';
import '../../fileTypeUtils/audio/bnkIO.dart';
import '../../fileTypeUtils/audio/modInstaller.dart';
import '../../fileTypeUtils/audio/waiExtractor.dart';
import '../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../fileTypeUtils/audio/wemToWavConverter.dart';
import '../../fileTypeUtils/bxm/bxmReader.dart';
import '../../fileTypeUtils/bxm/bxmWriter.dart';
import '../../fileTypeUtils/dat/datRepacker.dart';
import '../../fileTypeUtils/pak/pakRepacker.dart';
import '../../fileTypeUtils/ruby/pythonRuby.dart';
import '../../fileTypeUtils/yax/xmlToYax.dart';
import '../../fileTypeUtils/yax/yaxToXml.dart';
import '../../main.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../../widgets/misc/confirmCancelDialog.dart';
import '../../widgets/misc/confirmDialog.dart';
import 'FileHierarchy.dart';
import '../Property.dart';
import '../events/searchPanelEvents.dart';
import '../hasUuid.dart';
import '../openFiles/openFileTypes.dart';
import '../openFiles/openFilesManager.dart';
import '../preferencesData.dart';
import '../undoable.dart';
import '../listNotifier.dart';
import '../xmlProps/xmlProp.dart';

class HierarchyEntryAction {
  final String name;
  final IconData? icon;
  final double iconScale;
  final void Function() action;

  const HierarchyEntryAction({ required this.name, this.icon, this.iconScale = 1.0, required this.action });
}

mixin HierarchyEntryBase {
  final ListNotifier<HierarchyEntry> _children = ValueListNotifier([]);
  IterableNotifier<HierarchyEntry> get children => _children;

  void add(HierarchyEntry child) {
    _children.add(child);
    openHierarchyManager.treeViewIsDirty.value = true;
  }

  void addAll(Iterable<HierarchyEntry> children) {
    _children.addAll(children);
    openHierarchyManager.treeViewIsDirty.value = true;
  }

  void insert(int index, HierarchyEntry child) {
    _children.insert(index, child);
    openHierarchyManager.treeViewIsDirty.value = true;
  }

  void remove(HierarchyEntry child) {
    _children.remove(child);
    openHierarchyManager.treeViewIsDirty.value = true;
  }

  void clear() {
    _children.clear();
    openHierarchyManager.treeViewIsDirty.value = true;
  }

  void replaceWith(List<HierarchyEntry> newChildren) {
    _children.replaceWith(newChildren);
  }

  void updateOrReplaceWith(List<HierarchyEntry> newChildren, HierarchyEntry Function(Undoable) copy) {
    _children.updateOrReplaceWith(newChildren, copy);
  }

  void dispose() {
    _children.dispose();
  }
}

abstract class HierarchyEntry with HasUuid, Undoable, HierarchyEntryBase {
  OptionalFileInfo? optionalFileInfo;
  final StringProp name;
  final bool isSelectable;
  final ValueNotifier<bool> isSelected = ValueNotifier(false);
  final bool isCollapsible;
  final ValueNotifier<bool> isCollapsed = ValueNotifier(false);
  final bool isOpenable;
  final ValueNotifier<bool> isVisibleWithSearch = ValueNotifier(true);

  HierarchyEntry(this.name, this.isSelectable, this.isCollapsible, this.isOpenable) {
    isCollapsed.addListener(onTreeViewChanged);
    isVisibleWithSearch.addListener(onTreeViewChanged);
  }

  @override
  void dispose() {
    super.dispose();
    name.dispose();
    isSelected.dispose();
    isCollapsed.dispose();
    isVisibleWithSearch.dispose();
  }

  void onTreeViewChanged() {
    if (undoHistoryManager.isPushing)
      return;
    openHierarchyManager.treeViewIsDirty.value = true;
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
          action: () => openHierarchyManager.remove(this),
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

  // 3 methods for checking if is visible with search
  // 3 steps:
  //   1. set isVisibleWithSearch to false for all entries
  //   2. for each entry, check and store if it is visible with search
  //   3. propagate visibility to parents and children (if an entry is visible, all its parents and children are visible)
  void setIsVisibleWithSearchRecursive(bool value) {
    isVisibleWithSearch.value = value;
    for (var child in children) {
      child.setIsVisibleWithSearchRecursive(value);
    }
  }
  void computeIsVisibleWithSearchFilter() {
    var search = openHierarchySearch.value.toLowerCase();
    if (search.isEmpty)
      isVisibleWithSearch.value = true;
    else if (name.toString().toLowerCase().contains(search))
      isVisibleWithSearch.value = true;
    else
      isVisibleWithSearch.value = false;
    for (var child in children) {
      child.computeIsVisibleWithSearchFilter();
    }
  }
  void propagateVisibility(Map<HierarchyEntry, HierarchyEntry?> parentMap) {
    if (!isVisibleWithSearch.value) {
      for (var child in children)
        child.propagateVisibility(parentMap);
      return;
    }
    
    var parent = parentMap[this];
    while (parent != null) {
      parent.isVisibleWithSearch.value = true;
      parent = parentMap[parent];
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
    entry.isSelected.value = isSelected.value;
    entry.isCollapsed.value = isCollapsed.value;
    entry.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return entry;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as HierarchyEntry;
    isSelected.value = entry.isSelected.value;
    isCollapsed.value = entry.isCollapsed.value;
    updateOrReplaceWith(entry.children.toList(), (entry) => entry.takeSnapshot() as HierarchyEntry);
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
