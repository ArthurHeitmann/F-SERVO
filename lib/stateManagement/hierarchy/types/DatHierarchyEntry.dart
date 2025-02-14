
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../main.dart';
import '../../../utils/utils.dart';
import '../../../widgets/FileHierarchyExplorer/datFilesSelector.dart';
import '../../../widgets/misc/confirmDialog.dart';
import '../../Property.dart';
import '../../preferencesData.dart';
import '../../undoable.dart';
import '../FileHierarchy.dart';
import '../HierarchyEntryTypes.dart';
import 'PakHierarchyEntry.dart';
import 'PassiveFileHierarchyEntry.dart';
import 'RubyScriptHierarchyEntry.dart';
import 'XmlScriptHierarchyEntry.dart';

class DatHierarchyEntry extends ExtractableHierarchyEntry {
  final bool srcDatExists;
  String? lastExportPath;

  DatHierarchyEntry(StringProp name, String path, String extractedPath, {this.srcDatExists = true})
      : super(name, path, extractedPath, true, false, priority: 1000);

  @override
  Undoable takeSnapshot() {
    var entry = DatHierarchyEntry(name.takeSnapshot() as StringProp, path, extractedPath);
    entry.overrideUuid(uuid);
    entry.isSelected.value = isSelected.value;
    entry.isCollapsed.value = isCollapsed.value;
    entry.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return entry;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as DatHierarchyEntry;
    name.restoreWith(entry.name);
    isSelected.value = entry.isSelected.value;
    isCollapsed.value = entry.isCollapsed.value;
    updateOrReplaceWith(entry.children.toList(), (entry) => entry.takeSnapshot() as HierarchyEntry);
  }

  Future<void> loadChildren(List<String>? datFilePaths) async {
    var existingChildren = openHierarchyManager
      .findAllRecWhere((entry) => entry is FileHierarchyEntry && dirname(entry.path) == extractedPath);
    for (var child in existingChildren)
      openHierarchyManager.parentOf(child).remove(child);

    List<Future<void>> futures = [];
    datFilePaths ??= (await getDatFileList(extractedPath, removeDuplicates: true)).files;
    RubyScriptGroupHierarchyEntry? rubyScriptGroup;
    var prefs = PreferencesData();
    const supportedFileEndings = { ".pak", "_scp.bin", ".tmd", ".smd", ".mcd", ".ftb", ".bnk", ".wta", ".wtb", ".est", ".sst", ".ctx", ".uid", ".wmb", ".scr", ...bxmExtensions, ...datExtensions };
    for (var file in datFilePaths) {
      var isSupportedFile = supportedFileEndings.any((ending) => file.endsWith(ending));
      if (!isSupportedFile && !prefs.showAllDatFiles!.value)
        continue;
      int existingChildI = existingChildren.indexWhere((entry) => (entry as FileHierarchyEntry).path == file);
      if (existingChildI != -1) {
        var existingChild = existingChildren.removeAt(existingChildI);
        add(existingChild);
        continue;
      }
      if (file.endsWith("_scp.bin")) {
        if (rubyScriptGroup == null) {
          rubyScriptGroup = RubyScriptGroupHierarchyEntry();
          add(rubyScriptGroup);
        }
        futures.add(openHierarchyManager.openBinMrbScript(file, parent: rubyScriptGroup));
      }
      else if (isSupportedFile) {
        futures.add(openHierarchyManager.openFile(file, parent: this));
      }
      else {
        var entry = PassiveFileHierarchyEntry(StringProp(basename(file), fileId: null), file);
        add(entry);
      }
    }

    await Future.wait(futures);

    // leftover existing children are no longer in the DAT
    for (var child in existingChildren)
      child.dispose();

    if (rubyScriptGroup != null) {
      rubyScriptGroup.name.value += " (${rubyScriptGroup.children.length})";
      if (rubyScriptGroup.children.length > 8)
        rubyScriptGroup.isCollapsed.value = true;
    }

    sortChildren((a, b) {
      if (a.priority != b.priority)
        return b.priority - a.priority;
      return a.name.value.toLowerCase().compareTo(b.name.value.toLowerCase());
    });
  }

  Future<void> reloadChildren() async {
    for (var child in children.toList())
      remove(child, dispose: true);
    await loadChildren(null);
  }

  Future<void> addNewRubyScript() async {
    if (await confirmDialog(getGlobalContext(), title: "Add new Ruby Script?") != true)
      return;
    var scriptGroup = children.firstWhere(
            (entry) => entry is RubyScriptGroupHierarchyEntry,
        orElse: () => RubyScriptGroupHierarchyEntry()
    ) as RubyScriptGroupHierarchyEntry;
    scriptGroup.name.value = "Ruby Scripts (${scriptGroup.children.length + 1})";
    if (!children.contains(scriptGroup))
      add(scriptGroup);
    await scriptGroup.addNewRubyScript(path, extractedPath);
  }

  Future<void> repackDatAction() async {
    var datPath = await exportDat(extractedPath, checkForNesting: true);
    if (datPath != null)
      lastExportPath = datPath;
  }

  Future<void> repackDatToLastAction() async {
    await exportDat(extractedPath, datExportPath: lastExportPath, checkForNesting: true);
  }

  Future<void> repackOverwriteDatAction() async {
    await exportDat(extractedPath, overwriteOriginal: true);
  }

  @override
  List<HierarchyEntryAction> getActions() {
    var scriptRelatedClasses = [RubyScriptGroupHierarchyEntry, RubyScriptHierarchyEntry, XmlScriptHierarchyEntry, PakHierarchyEntry];
    var prefs = PreferencesData();
    return [
      HierarchyEntryAction(
        name: "Repack DAT",
        icon: Icons.file_upload,
        action: repackDatAction,
      ),
      if (lastExportPath != null && (prefs.dataExportPath?.value ?? "").isEmpty)
        HierarchyEntryAction(
          name: "Repack DAT to last location",
          icon: Icons.file_upload,
          action: repackDatToLastAction,
        ),
      if (srcDatExists)
        HierarchyEntryAction(
          name: "Repack DAT (overwrite)",
          icon: Icons.file_upload,
          action: repackOverwriteDatAction,
        ),
      HierarchyEntryAction(
        name: "Change packed files",
        icon: Icons.folder_open,
        action: () => showDatSelectorPopup(this),
      ),
      if (children.where((child) => scriptRelatedClasses.any((type) => child.runtimeType == type)).isNotEmpty)
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
      HierarchyEntryAction(
        name: "Reload children",
        icon: Icons.refresh,
        action: reloadChildren,
      ),
      ...super.getContextMenuActions()
    ];
  }
}
