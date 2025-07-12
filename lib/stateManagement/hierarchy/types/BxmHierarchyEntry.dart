
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/bxm/bxmReader.dart';
import '../../../fileTypeUtils/bxm/bxmWriter.dart';
import '../../../utils/utils.dart';
import '../../Property.dart';
import '../HierarchyEntryTypes.dart';

class BxmHierarchyEntry extends FileHierarchyEntry {
  final String xmlPath;

  BxmHierarchyEntry(StringProp name, String path, {String? xmlPath})
      : xmlPath = xmlPath ?? "$path.xml",
        super(name, path, false, true, priority: 10) {
    supportsVsCodeEditing = true;
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
