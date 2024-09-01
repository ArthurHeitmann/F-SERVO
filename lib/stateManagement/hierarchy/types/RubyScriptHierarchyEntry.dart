
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/ruby/pythonRuby.dart';
import '../../../utils/utils.dart';
import '../../Property.dart';
import '../../undoable.dart';
import '../FileHierarchy.dart';
import '../HierarchyEntryTypes.dart';
import 'DatHierarchyEntry.dart';

class RubyScriptGroupHierarchyEntry extends HierarchyEntry {
  RubyScriptGroupHierarchyEntry()
    : super(StringProp("Ruby Scripts", fileId: null), false, true, false, priority: 100);

  @override
  Undoable takeSnapshot() {
    var snapshot = RubyScriptGroupHierarchyEntry();
    snapshot.overrideUuid(uuid);
    snapshot.isSelected.value = isSelected.value;
    snapshot.isCollapsed.value = isCollapsed.value;
    snapshot.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as RubyScriptGroupHierarchyEntry;
    isCollapsed.value = entry.isCollapsed.value;
    updateOrReplaceWith(entry.children.toList(), (obj) => obj.takeSnapshot() as HierarchyEntry);
  }

  Future<void> addNewRubyScript(String datPath, String datExtractedPath) async {
    var datInfoPath = join(datExtractedPath, "dat_info.json");
    Map datInfo;
    if (await File(datInfoPath).exists()) {
      datInfo = jsonDecode(await File(datInfoPath).readAsString());
    } else {
      datInfo = {
        "version": 1,
        "files": (await getDatFileList(datExtractedPath))
            .map((path) => basename(path))
            .toList(),
        "basename": basenameWithoutExtension(datPath),
        "ext": "dat",
      };
    }

    var newScriptBin = "${basenameWithoutExtension(datPath)}_${randomId().toRadixString(16)}_scp.bin";
    var newScriptRb = "$newScriptBin.rb";
    var datFiles = (datInfo["files"] as List).cast<String>();
    datFiles.add(newScriptBin);
    datFiles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    datInfo["files"] = datFiles;

    var newScriptPath = join(datExtractedPath, newScriptRb);
    const scriptTemplate = """
proxy = ScriptProxy.new()
class << proxy
	# DIALOGUE

	# EVENT CALLBACKS
  
	# EVENT TRIGGERS
	def update()
	end
end

Fiber.new() { proxy.update() }
""";
    await File(newScriptPath).writeAsString(scriptTemplate);
    await rubyFileToBin(newScriptPath);
    await File(datInfoPath).writeAsString(const JsonEncoder.withIndent("\t").convert(datInfo));

    var newScriptEntry = RubyScriptHierarchyEntry(StringProp(newScriptRb, fileId: null), newScriptPath);
    add(newScriptEntry);
    newScriptEntry.onOpen();
  }
}

class RubyScriptHierarchyEntry extends GenericFileHierarchyEntry {
  RubyScriptHierarchyEntry(StringProp name, String path)
      : super(name, path, false, true) {
    supportsVsCodeEditing = true;
  }

  @override
  HierarchyEntry clone() {
    return RubyScriptHierarchyEntry(name.takeSnapshot() as StringProp, path);
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Compile to .bin",
        icon: Icons.file_upload,
        action: () async {
          var success = await rubyFileToBin(path);
          if (success)
            showToast("Success!");
          else
            return;
          var datPath = dirname(path);
          if (!strEndsWithDat(datPath))
            return;
          var parent = openHierarchyManager.parentOf(this);
          if (parent is! DatHierarchyEntry) {
            if (parent is HierarchyEntry)
              parent = openHierarchyManager.parentOf(parent);
            else
              return;
          }
          if (parent is! DatHierarchyEntry)
            return;
          await parent.repackDatAction();
        },
      ),
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
