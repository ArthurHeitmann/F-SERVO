
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/yax/xmlToYax.dart';
import '../../../utils/utils.dart';
import '../../Property.dart';
import '../../openFiles/openFilesManager.dart';
import '../../undoable.dart';
import '../FileHierarchy.dart';
import '../HierarchyEntryTypes.dart';

class XmlScriptHierarchyEntry extends FileHierarchyEntry {
  int groupId = -1;
  bool _hasReadMeta = false;
  final StringProp hapName = StringProp("", fileId: null);

  XmlScriptHierarchyEntry(StringProp name, String path, { bool? preferVsCode })
      : super(name, path, false, true)
  {
    this.name.transform = (str) {
      if (hapName.value.isNotEmpty)
        return "$str - ${tryToTranslate(hapName.value)}";
      return str;
    };
    supportsVsCodeEditing = preferVsCode ?? basename(path) == "0.xml";
  }

  bool get hasReadMeta => _hasReadMeta;

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
      hapName.value = name.first.text;

    _hasReadMeta = true;
  }

  @override
  Future<void> onOpen() async {
    if (await tryOpenInVsCode()) {
      openInVsCode(vsCodeEditingPath);
      return;
    }

    String? secondaryName = tryToTranslate(hapName.value);
    areasManager.openFile(path, secondaryName: secondaryName, optionalInfo: optionalFileInfo);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = XmlScriptHierarchyEntry(name.takeSnapshot() as StringProp, path);
    snapshot.overrideUuid(uuid);
    snapshot.isSelected.value = isSelected.value;
    snapshot.isCollapsed.value = isCollapsed.value;
    snapshot._hasReadMeta = _hasReadMeta;
    snapshot.hapName.value = hapName.value;
    snapshot.groupId = groupId;
    snapshot.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as XmlScriptHierarchyEntry;
    name.restoreWith(entry.name);
    isSelected.value = entry.isSelected.value;
    isCollapsed.value = entry.isCollapsed.value;
    _hasReadMeta = entry._hasReadMeta;
    hapName.value = entry.hapName.value;
    updateOrReplaceWith(entry.children.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
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
