
import 'dart:io';

import 'package:path/path.dart';

import '../../../fileTypeUtils/audio/audioModsMetadata.dart';
import '../../../fileTypeUtils/audio/bnkWemIdsToPlaylists.dart';
import '../../../fileTypeUtils/audio/waiIO.dart';
import '../../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class WaiFileData extends OpenFileData {
  Set<WemPatch> pendingPatches = {};
  String? bgmBnkPath;
  Map<int, Set<int>> wemIdsToBnkPlaylists = {};

  WaiFileData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.none);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var bnkPath = join(dirname(path), "bgm", "BGM.bnk");
    if (await File(bnkPath).exists()) {
      wemIdsToBnkPlaylists.addAll(await getWemIdsToBnkPlaylists(bnkPath));
    } else {
      showToast("BGM.bnk not found");
    }

    await super.load();
  }

  Future<WaiFile> loadWai() async {
    var bytes = await ByteDataWrapper.fromFile(path);
    return WaiFile.read(bytes);
  }

  Future<void> processPendingPatches() async {
    if (pendingPatches.isEmpty)
      return;

    var exportDir = join(dirname(path), "stream");
    // update WSPs & wai data
    var wai = await loadWai();
    await wai.patchWems(pendingPatches.toList(), exportDir);
    // save wai
    var fileSize = wai.size;
    var bytes = ByteDataWrapper.allocate(fileSize);
    wai.write(bytes);
    await backupFile(path);
    await bytes.save(path);

    // update metadata
    await AudioModsMetadata.lock();
    try {
      var metadataPath = join(dirname(path), audioModsMetadataFileName);
      var metadata = await AudioModsMetadata.fromFile(metadataPath);
      for (var patch in pendingPatches)
        metadata.moddedWaiChunks[patch.wemID] = AudioModChunkInfo(patch.wemID);
      await metadata.toFile(metadataPath);
    } finally {
      AudioModsMetadata.unlock();
    }

    pendingPatches.clear();

    // write wai
    await save();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = WaiFileData(name.value, path);
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as WaiFileData;
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
  }
}
