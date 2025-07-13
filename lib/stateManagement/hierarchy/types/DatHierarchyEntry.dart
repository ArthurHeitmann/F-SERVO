
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileSystem/FileSystem.dart';
import '../../../main.dart';
import '../../../utils/utils.dart';
import '../../../widgets/FileHierarchyExplorer/datFilesSelector.dart';
import '../../../widgets/misc/confirmDialog.dart';
import '../../Property.dart';
import '../../changesExporter.dart';
import '../../events/statusInfo.dart';
import '../../preferencesData.dart';
import '../FileHierarchy.dart';
import '../HierarchyEntryTypes.dart';
import 'PakHierarchyEntry.dart';
import 'PassiveFileHierarchyEntry.dart';
import 'RubyScriptHierarchyEntry.dart';
import 'XmlScriptHierarchyEntry.dart';

class DatHierarchyEntry extends ExtractableHierarchyEntry {
  final bool srcDatExists;
  String? lastExportPath;
  Future<void> Function()? beforeLoadChildren;
  bool needsToLoadChildren = false;
  bool allowLoadingChildren = false;

  DatHierarchyEntry(StringProp name, String path, String extractedPath, {this.srcDatExists = true})
      : super(name, path, extractedPath, true, false, priority: 1000) {
    isCollapsed.addListener(_firstTimeLoadChildren);
  }

  Future<void> loadChildren(List<String>? datFilePaths) async {
    await beforeLoadChildren?.call();
    beforeLoadChildren = null;
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
      if (!FS.i.isVirtual(path))
        ...[
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
        ],
      HierarchyEntryAction(
        name: "Add file to DAT",
        icon: Icons.add,
        action: _addFileToDat,
      ),
      if (!FS.i.isVirtual(path))
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
      if (!FS.i.useVirtualFs)
        HierarchyEntryAction(
          name: "Reload children",
          icon: Icons.refresh,
          action: reloadChildren,
        ),
      ...super.getContextMenuActions()
    ];
  }

  Future<void> _addFileToDat() async {
    var files = await FS.i.selectFiles();
    if (files.isEmpty)
      return;
    var file = files.first;
    var fileName = basename(file);
    if (extension(file).length > 4) {
      showToast("File extension must be <= 3 characters");
      return;
    }

    var newPath = join(extractedPath, fileName);
    await FS.i.copyFile(file, newPath);

    var datInfoPath = join(extractedPath, "dat_info.json");
    if (!await FS.i.existsFile(datInfoPath)) {
      messageLog.add("File was not extracted with F-SERVO. Missing dat_info.json");
      return;
    }
    var datInfo = jsonDecode(await FS.i.readAsString(datInfoPath));

    var datFiles = (datInfo["files"] as List).cast<String>();
    datFiles.add(fileName);
    datInfo["files"] = datFiles;

    await FS.i.writeAsString(datInfoPath, const JsonEncoder.withIndent("\t").convert(datInfo));

    isDirty.value = true;
    changedDatFiles.add(extractedPath);
    await processChangedFiles();

    await openHierarchyManager.openFile(newPath, parent: this);
    
    showToast("Added $fileName to ${name.value}");
  }

  Future<void> _firstTimeLoadChildren() async {
    if (isCollapsed.value)
      return;
    if (!needsToLoadChildren) {
      isCollapsed.removeListener(_firstTimeLoadChildren);
      return;
    }
    if (!allowLoadingChildren) {
      isCollapsed.value = true;
      return;
    }
    isCollapsed.removeListener(_firstTimeLoadChildren);
    await loadChildren(null);
  }
}
