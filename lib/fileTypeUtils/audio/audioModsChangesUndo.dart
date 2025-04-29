

import 'package:path/path.dart';

import '../../main.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/utils.dart';
import '../../widgets/misc/confirmDialog.dart';
import '../utils/ByteDataWrapper.dart';
import 'audioModsMetadata.dart';
import 'waiIO.dart';
import '../../fileSystem/FileSystem.dart';

Future<void> revertAllAudioMods(String waiPath) async {
  var metadataPath = join(dirname(waiPath), audioModsMetadataFileName);
  if (!await FS.i.existsFile(metadataPath)) {
    showToast("No audio mods metadata file found");
    return;
  }
  var metadata = await AudioModsMetadata.fromFile(metadataPath);
  var wai = WaiFile.read(await ByteDataWrapper.fromFile(waiPath));
  var wwiseInfoPath = join(dirname(waiPath), "WwiseInfo.wai");
  var bgmBankPath = join(dirname(waiPath), "bgm", "BGM.bnk");
  var prefs = PreferencesData();
  var extractDir = prefs.waiExtractDir!.value;

  List<String> changedFiles = [
    if (metadata.moddedWaiChunks.isNotEmpty)
      waiPath,
    if (metadata.moddedWaiEventChunks.isNotEmpty)
      wwiseInfoPath,
    if (metadata.moddedBnkChunks.isNotEmpty)
      bgmBankPath,
  ];

  for (var wemId in metadata.moddedWaiChunks.keys) {
    var wemIndex = wai.getIndexFromId(wemId);
    var wem = wai.wemStructs[wemIndex];
    var dir = wai.getWemDirectoryFromI(wemIndex);
    var wspName = wem.wemToWspName(wai.wspNames);
    // extracted WEM
    var wspExtractDir = extractDir;
    if (dir != null)
      wspExtractDir = join(wspExtractDir, dir);
    wspExtractDir = join(wspExtractDir, wspName);
    var files = await FS.i.listFiles(wspExtractDir)
      .where((f) => f.endsWith("$wemId.wem"))
      .toList();
    if (files.length != 1)
      print("Warning: found ${files.length} files for WEM $wemId");
    changedFiles.add(files[0]);
    // modded WSP
    var wspPath = join(dirname(waiPath), "stream");
    if (dir != null)
      wspPath = join(wspPath, dir);
    wspPath = join(wspPath, wspName);
    changedFiles.add(wspPath);
  }
  changedFiles = changedFiles.toSet().toList();
  changedFiles.sort();

  if (changedFiles.isEmpty) {
    showToast("No files to restore");
    return;
  }

  var confirmation = await confirmDialog(
    getGlobalContext(),
    title: "Revert ${pluralStr(changedFiles.length, "file")}?",
    body: "Based on $audioModsMetadataFileName\n"
      "The following files will be restored:\n"
      "${changedFiles.map((f) => "- $f").join("\n")}"
  );
  if (confirmation != true)
    return;

  int restoreCount = 0;
  int warningCount = 0;
  for (var changedFile in changedFiles) {
    var backupPath = "$changedFile.backup";
    if (!await FS.i.existsFile(backupPath)) {
      messageLog.add("Backup file not found for $changedFile");
      warningCount++;
      continue;
    }
    try {
      if (await FS.i.existsFile(changedFile))
        await FS.i.delete(changedFile);
      await FS.i.renameFile(backupPath, changedFile);
      restoreCount++;
    } catch (e, s) {
      messageLog.add("Failed to restore $changedFile");
      print("$e\n$s");
      warningCount++;
    }
  }

  metadata.name = null;
  metadata.moddedWaiChunks.clear();
  metadata.moddedWaiEventChunks.clear();
  metadata.moddedBnkChunks.clear();
  await metadata.toFile(metadataPath);

  if (restoreCount == 0)
    showToast("No files to restore");
  else
    showToast(
    "Restored ${pluralStr(restoreCount, "file")}"
    "${warningCount > 0 ? ", ${pluralStr(warningCount, "warning")}" : ""}"
  );
}
