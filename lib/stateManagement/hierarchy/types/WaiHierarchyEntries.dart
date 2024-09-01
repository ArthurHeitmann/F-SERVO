
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/audio/audioModPacker.dart';
import '../../../fileTypeUtils/audio/audioModsChangesUndo.dart';
import '../../../fileTypeUtils/audio/convertStreamedToInMemory.dart';
import '../../../fileTypeUtils/audio/modInstaller.dart';
import '../../../fileTypeUtils/audio/waiExtractor.dart';
import '../../../fileTypeUtils/audio/wemToWavConverter.dart';
import '../../../utils/utils.dart';
import '../../Property.dart';
import '../../openFiles/openFilesManager.dart';
import '../../openFiles/types/WemFileData.dart';
import '../../undoable.dart';
import '../HierarchyEntryTypes.dart';

class WaiHierarchyEntry extends ExtractableHierarchyEntry {
  OpenFileId waiDataId;
  List<WaiChild> structure = [];

  WaiHierarchyEntry(StringProp name, String path, String extractedPath, this.waiDataId)
    : super(name, path, extractedPath, true, false);

  @override
  Undoable takeSnapshot() {
    var snapshot =  WaiHierarchyEntry(name.takeSnapshot() as StringProp, path, extractedPath, waiDataId);
    snapshot.overrideUuid(uuid);
    snapshot.isSelected.value = isSelected.value;
    snapshot.isCollapsed.value = isCollapsed.value;
    snapshot.structure = structure;
    snapshot.replaceWith(children.map((entry) => entry.takeSnapshot() as HierarchyEntry).toList());
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as WaiHierarchyEntry;
    name.restoreWith(entry.name);
    isSelected.value = entry.isSelected.value;
    isCollapsed.value = entry.isCollapsed.value;
    updateOrReplaceWith(entry.children.toList(), (entry) => entry.takeSnapshot() as HierarchyEntry);
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Package Mod",
        icon: Icons.file_upload,
        action: () => packAudioMod(path),
      ),
      HierarchyEntryAction(
        name: "Install Packaged Mod",
        icon: Icons.add,
        action: () => installMod(path),
      ),
      HierarchyEntryAction(
        name: "Revert all changes",
        icon: Icons.undo,
        action: () => revertAllAudioMods(path),
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

class WaiFolderHierarchyEntry extends GenericFileHierarchyEntry {
  final String bgmBnkPath;

  WaiFolderHierarchyEntry(StringProp name, String path, List<WaiChild> children)
      : bgmBnkPath = join(dirname(path), "bgm", "BGM.bnk"),
        super(name, path, true, false) {
    isCollapsed.value = true;
    addAll(children.map((child) => makeWaiChildEntry(child, bgmBnkPath)));
  }
  WaiFolderHierarchyEntry.clone(WaiFolderHierarchyEntry other)
      : bgmBnkPath = other.bgmBnkPath,
        super(other.name.takeSnapshot() as StringProp, other.path, true, false) {
    isCollapsed.value = other.isCollapsed.value;
    addAll(other.children.map((entry) => (entry as GenericFileHierarchyEntry).clone()));
  }

  @override
  HierarchyEntry clone() {
    return WaiFolderHierarchyEntry.clone(this);
  }
}

class WspHierarchyEntry extends GenericFileHierarchyEntry {
  final List<WaiChild> _childWems;
  final String bgmBnkPath;

  WspHierarchyEntry(StringProp name, String path, List<WaiChild> childWems, this.bgmBnkPath) :
        _childWems = childWems,
        super(name, path, true, false) {
    isCollapsed.value = true;
    addAll(childWems.map((child) => makeWaiChildEntry(child, bgmBnkPath)));
  }

  @override
  HierarchyEntry clone() {
    return WspHierarchyEntry(name.takeSnapshot() as StringProp, path, _childWems, bgmBnkPath);
  }

  Future<void> exportAsWav() async {
    var saveDir = await FilePicker.platform.getDirectoryPath();
    if (saveDir == null)
      return;
    var wspDir = join(saveDir, basename(path));
    await Directory(wspDir).create(recursive: true);
    await Future.wait(
      children.whereType<WemHierarchyEntry>()
          .map((e) => e.exportAsWav(
        wavPath:  join(wspDir, "${basenameWithoutExtension(e.path)}.wav"),
        displayToast: false,
      )),
    );
    showToast("Saved ${children.length} WEMs");
  }

  @override
  List<HierarchyEntryAction> getActions() {
    return [
      HierarchyEntryAction(
        name: "Save all as WAV",
        icon: Icons.file_download,
        action: exportAsWav,
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

class WemHierarchyEntry extends GenericFileHierarchyEntry {
  final int wemId;

  WemHierarchyEntry(StringProp name, String path, this.wemId, OptionalWemData? optionalWemData)
      : super(name, path, false, true) {
    optionalFileInfo = optionalWemData;
  }

  @override
  HierarchyEntry clone() {
    return WemHierarchyEntry(name.takeSnapshot() as StringProp, path, wemId, optionalFileInfo as OptionalWemData?);
  }

  Future<void> exportAsWav({ String? wavPath, bool displayToast = true }) async {
    wavPath ??= await FilePicker.platform.saveFile(
      fileName: "${basenameWithoutExtension(path)}.wav",
      allowedExtensions: ["wav"],
      type: FileType.custom,
    );
    if (wavPath == null)
      return;
    await wemToWav(path, wavPath);
    if (displayToast)
      showToast("Saved as ${basename(wavPath)}");
  }

  @override
  List<HierarchyEntryAction> getActions() {
    var fileInfo = optionalFileInfo;
    return [
      HierarchyEntryAction(
        name: "Save as WAV",
        icon: Icons.file_download,
        action: exportAsWav,
      ),
      if (fileInfo is OptionalWemData && fileInfo.isPrefetched)
        HierarchyEntryAction(
          name: "Make in memory",
          icon: Icons.swap_horiz,
          action: () => convertStreamedToInMemory(fileInfo.bnkPath, wemId),
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

HierarchyEntry makeWaiChildEntry(WaiChild child, String bgmBnkPath) {
  HierarchyEntry entry;
  if (child is WaiChildDir)
    entry = WaiFolderHierarchyEntry(StringProp(child.name, fileId: null), child.path, child.children);
  else if (child is WaiChildWsp)
    entry = WspHierarchyEntry(StringProp(child.name, fileId: null), child.path, child.children, bgmBnkPath);
  else if (child is WaiChildWem)
    entry = WemHierarchyEntry(
        StringProp(child.name, fileId: null),
        child.path,
        child.wemId,
        OptionalWemData(bgmBnkPath, WemSource.wsp)
    );
  else
    throw Exception("Unknown WAI child type: ${child.runtimeType}");
  return entry;
}
