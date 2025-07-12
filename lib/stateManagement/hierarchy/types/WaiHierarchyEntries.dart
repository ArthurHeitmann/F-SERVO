

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
import '../HierarchyEntryTypes.dart';
import '../../../fileSystem/FileSystem.dart';

class WaiHierarchyEntry extends ExtractableHierarchyEntry {
  OpenFileId waiDataId;
  List<WaiChild> structure = [];

  WaiHierarchyEntry(StringProp name, String path, String extractedPath, this.waiDataId)
    : super(name, path, extractedPath, true, false);

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

class WaiFolderHierarchyEntry extends FileHierarchyEntry {
  final String bgmBnkPath;

  WaiFolderHierarchyEntry(StringProp name, String path, List<WaiChild> children)
      : bgmBnkPath = join(dirname(path), "bgm", "BGM.bnk"),
        super(name, path, true, false) {
    isCollapsed.value = true;
    addAll(children.map((child) => makeWaiChildEntry(child, bgmBnkPath)));
  }
}

class WspHierarchyEntry extends FileHierarchyEntry {
  final String bgmBnkPath;

  WspHierarchyEntry(StringProp name, String path, List<WaiChild> childWems, this.bgmBnkPath) :
        super(name, path, true, false) {
    isCollapsed.value = true;
    addAll(childWems.map((child) => makeWaiChildEntry(child, bgmBnkPath)));
  }

  Future<void> exportAsWav() async {
    var saveDir = await FS.i.selectDirectory();
    if (saveDir == null)
      return;
    var wspDir = join(saveDir, basename(path));
    await FS.i.createDirectory(wspDir);
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

class WemHierarchyEntry extends FileHierarchyEntry {
  final int wemId;

  WemHierarchyEntry(StringProp name, String path, this.wemId, OptionalWemData? optionalWemData)
      : super(name, path, false, true) {
    optionalFileInfo = optionalWemData;
  }

  Future<void> exportAsWav({ String? wavPath, bool displayToast = true }) async {
    if (FS.i.isVirtual(path)) {
      var tmpWav = await wemToWavTmp(path);
      var wavBytes = await FS.i.read(tmpWav);
      await FS.i.saveFile(
        fileName: "${basenameWithoutExtension(path)}.wav",
        bytes: wavBytes,
      );
      await FS.i.delete(tmpWav);
    }
    else {
      wavPath ??= await FS.i.selectSaveFile(
        fileName: "${basenameWithoutExtension(path)}.wav",
        allowedExtensions: ["wav"],
      );
      if (wavPath == null)
        return;
      await wemToWav(path, wavPath);
      if (displayToast)
        showToast("Saved as ${basename(wavPath)}");
    }
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
