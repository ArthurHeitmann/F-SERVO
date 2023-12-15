
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/dat/datRepacker.dart';
import '../../../main.dart';
import '../../../utils/utils.dart';
import '../../../widgets/misc/confirmDialog.dart';
import '../../Property.dart';
import '../../preferencesData.dart';
import '../../undoable.dart';
import '../HierarchyEntryTypes.dart';
import 'RubyScriptHierarchyEntry.dart';

class DatHierarchyEntry extends ExtractableHierarchyEntry {
  DatHierarchyEntry(StringProp name, String path, String extractedPath)
      : super(name, path, extractedPath, true, false);

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
