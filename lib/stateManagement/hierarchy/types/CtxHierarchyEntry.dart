
import 'package:flutter/material.dart';

import '../../../fileTypeUtils/ctx/ctxRepacker.dart';
import '../../Property.dart';
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
}
