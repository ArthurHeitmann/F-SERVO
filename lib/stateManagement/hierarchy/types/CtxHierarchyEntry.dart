
import 'package:flutter/material.dart';

import '../../../fileTypeUtils/ctx/ctxRepacker.dart';
import '../../Property.dart';
import '../../undoable.dart';
import '../HierarchyEntryTypes.dart';

class CtxHierarchyEntry extends ExtractableHierarchyEntry {

  CtxHierarchyEntry(StringProp name, String path, String extractedPath)
    : super(name, path, extractedPath, true, false, priority: 100);

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Repack",
        icon: Icons.file_upload,
        action: () => repackCtx(path, extractedPath),
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

  @override
  Undoable takeSnapshot() {
    var entry = CtxHierarchyEntry(name, path, extractedPath);
    entry.overrideUuid(uuid);
    entry.isSelected.value = isSelected.value;
    entry.isCollapsed.value = isCollapsed.value;
    entry.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return entry;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as HierarchyEntry;
    name.restoreWith(entry.name);
    isSelected.value = entry.isSelected.value;
    isCollapsed.value = entry.isCollapsed.value;
    updateOrReplaceWith(entry.children.toList(), (entry) => entry.takeSnapshot() as HierarchyEntry);
  }
}
