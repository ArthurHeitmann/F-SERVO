// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member


import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/audio/bnkPatcher.dart';
import '../../../fileTypeUtils/audio/bnkWemIdsToPlaylists.dart';
import '../../../fileTypeUtils/audio/riffParser.dart';
import '../../../fileTypeUtils/audio/waiIO.dart';
import '../../../fileTypeUtils/audio/wavToWemConverter.dart';
import '../../../utils/Disposable.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../audioResourceManager.dart';
import '../../changesExporter.dart';
import '../../hasUuid.dart';
import '../../hierarchy/FileHierarchy.dart';
import '../../hierarchy/HierarchyEntryTypes.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import '../openFilesManager.dart';
import 'WaiFileData.dart';
import '../../../fileSystem/FileSystem.dart';

mixin AudioFileData on HasUuid implements Disposable {
  AudioResource? resource;
  bool cuePointsStartAt1 = false;
  abstract final ValueNotifier<String> name;

  Future<void> load();

  @override
  void dispose();
}
class WavFileData with HasUuid, AudioFileData {
  @override
  final ValueNotifier<String> name;
  String path;

  WavFileData(this.path)
      : name = ValueNotifier(basename(path));

  @override
  Future<void> load() async {
    resource = await audioResourcesManager.getAudioResource(path, makeCopy: true);
  }

  @override
  void dispose() {
    resource?.dispose();
    resource = null;
    name.dispose();
  }
}

enum WemSource {
  wsp, bnk
}
class OptionalWemData extends OptionalFileInfo {
  final String bnkPath;
  final WemSource source;
  final bool isStreamed;
  final bool isPrefetched;

  const OptionalWemData(this.bnkPath, this.source, { this.isStreamed = false, this.isPrefetched = false });
}

class WemFileData extends OpenFileData with AudioFileData {
  final ValueNotifier<AudioFileData?> overrideData = ValueNotifier(null);
  late final BoolProp usesLoudnessNormalization;
  bool usesSeekTable = false;
  final ChangeNotifier onOverrideApplied = ChangeNotifier();
  final ValueNotifier<bool> isReplacing = ValueNotifier(false);
  final Set<int> relatedBnkPlaylistIds = {};

  OptionalWemData? get wemInfo => super.optionalInfo as OptionalWemData?;

  WemFileData(super.name, super.path, { super.secondaryName, OptionalWemData? wemInfo }) :
        super(type: FileType.wem, icon: Icons.music_note) {
    usesLoudnessNormalization = BoolProp(false, fileId: uuid);
    optionalInfo = wemInfo;
  }

  @override
  Future<void> load([bool superReload = true]) async {
    if (loadingState.value != LoadingState.notLoaded && resource != null)
      return;
    loadingState.value = LoadingState.loading;

    // extract wav
    await resource?.dispose();
    resource = await audioResourcesManager.getAudioResource(path);

    // related bnk playlists
    var waiRes = areasManager.hiddenArea.files.whereType<WaiFileData>();
    if (waiRes.isNotEmpty && wemInfo?.source == WemSource.wsp) {
      var wai = waiRes.first;
      if (wai.wemIdsToBnkPlaylists.isNotEmpty) {
        var wemId = int.parse(RegExp(r"(\d+)\.wem").firstMatch(name.value)!.group(1)!);
        relatedBnkPlaylistIds.addAll(wai.wemIdsToBnkPlaylists[wemId] ?? []);
      }
    } else if (wemInfo?.source == WemSource.bnk) {
      var wemIdsToBnkPlaylists = await getWemIdsToBnkPlaylists(wemInfo!.bnkPath);
      var wemId = int.parse(RegExp(r"(\d+)\.wem").firstMatch(name.value)!.group(1)!);
      relatedBnkPlaylistIds.addAll(wemIdsToBnkPlaylists[wemId] ?? []);
    }

    // set usesSeekTable and usesLoudnessNormalization from WEM RIFF format
    var wemRiff = await RiffFile.fromFile(path);
    usesLoudnessNormalization.value = wemRiff.chunks.any((chunk) => chunk.chunkId == "akd ");
    if (wemRiff.format is WemFormatChunk)
      usesSeekTable = (wemRiff.format as WemFormatChunk).setupPacketOffset != 0;

    if (superReload)
      await super.load();
  }

  @override
  Future<void> save() async {
    var wemIdStr = RegExp(r"(\d+)\.wem").firstMatch(name.value)!.group(1)!;
    var wemId = int.parse(wemIdStr);
    if (wemInfo?.source == WemSource.wsp) {
      var wai = areasManager.hiddenArea.files.whereType<WaiFileData>().first;
      wai.pendingPatches.add(WemPatch(path, wemId));
    } else if (wemInfo?.source == WemSource.bnk) {
      await patchBnk(wemInfo!.bnkPath, wemId, path);
      var bnkEntry = openHierarchyManager.findRecWhere((e) => e is FileHierarchyEntry && e.path == wemInfo!.bnkPath);
      if (bnkEntry != null) {
        bnkEntry.hasSavedChanges.value = true;
        var bnkParent = openHierarchyManager.parentOf(bnkEntry);
        if (bnkParent is ExtractableHierarchyEntry && strEndsWithDat(bnkParent.path)) {
          changedDatFiles.add(bnkParent.extractedPath);
        } else {
          bnkEntry.isDirty.value = true;
        }
      }
    } else {
      showToast("Unknown WEM source (not WSP or BNK)");
    }

    await super.save();
  }

  @override
  void dispose() {
    if (resource != null) {
      resource!.dispose();
      resource = null;
    }
    if (overrideData.value != null) {
      overrideData.value!.dispose();
      overrideData.value = null;
    }
    usesLoudnessNormalization.dispose();
    super.dispose();
  }

  Future<void> applyOverride(bool enableVolumeNormalization) async {
    if (overrideData.value == null)
      throw Exception("No override data");

    isReplacing.value = true;

    try {
      await backupFile(path);
      var overrideFile = overrideData.value!;
      if (overrideFile is WavFileData)
        await wavToWem(overrideFile.path, path, usesSeekTable);
      else if (overrideFile is WemFileData)
        await FS.i.copyFile(overrideFile.path, path);
      else
        throw Exception("Invalid override file type");
      overrideData.value!.dispose();
      overrideData.value = null;

      // reload
      await audioResourcesManager.reloadAudioResource(resource!);
      loadingState.value = LoadingState.notLoaded;
      await load(false);
      loadingState.value = LoadingState.loaded;

      onOverrideApplied.notifyListeners();
    } finally {
      setHasUnsavedChanges(true);
      isReplacing.value = false;
    }
  }

  Future<void> removeOverride() async {
    if (overrideData.value == null)
      return;

    overrideData.value!.dispose();
    overrideData.value = null;
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = WemFileData(
        name.value, path, secondaryName: secondaryName.value, wemInfo: wemInfo
    );
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.usesSeekTable = usesSeekTable;
    snapshot.usesLoudnessNormalization.value = usesLoudnessNormalization.value;
    snapshot.resource = resource?.newRef();
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as WemFileData;
    name.value = content.name.value;
    usesSeekTable = content.usesSeekTable;
    usesLoudnessNormalization.value = content.usesLoudnessNormalization.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
  }
}
