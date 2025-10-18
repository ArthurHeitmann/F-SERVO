
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

import '../../main.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../../widgets/misc/textDialog.dart';
import '../utils/ByteDataWrapper.dart';
import 'audioModsMetadata.dart';
import 'waiIO.dart';

Future<void> packAudioMod(String waiPath) async {
  var metadataPath = join(dirname(waiPath), audioModsMetadataFileName);
  if (!await File(metadataPath).exists()) {
    showToast("No audio mods metadata fiel found");
    return;
  }
  var metadata = await AudioModsMetadata.fromFile(metadataPath);
  if (metadata.moddedBnkChunks.isEmpty && metadata.moddedWaiEventChunks.isEmpty && metadata.moddedWaiChunks.isEmpty) {
    showToast("No audio mods found");
    return;
  }
  var bgmBankPath = join(dirname(waiPath), "bgm", "BGM.bnk");
  var wwiseInfoPath = join(dirname(waiPath), "WwiseInfo.wai");
  var wai = WaiFile.read(await ByteDataWrapper.fromFile(waiPath));

  // collect all relevant files
  Set<String> changedFiles = {
    metadataPath,
    waiPath,
    if (metadata.moddedWaiEventChunks.isNotEmpty)
      wwiseInfoPath,
    if (metadata.moddedBnkChunks.isNotEmpty)
      bgmBankPath,
  };
  for (var wemId in metadata.moddedWaiChunks.keys) {
    var wemIndex = wai.getIndexFromId(wemId);
    var wem = wai.wemStructs[wemIndex];
    var dir = wai.getWemDirectoryFromI(wemIndex);
    var wspName = wem.wemToWspName(wai.wspNames);
    // modded WSP
    var wspPath = join(dirname(waiPath), "stream");
    if (dir != null)
      wspPath = join(wspPath, dir);
    wspPath = join(wspPath, wspName);
    changedFiles.add(wspPath);
  }

  // make sure all files exist
  int missingFiles = 0;
  for (var file in changedFiles) {
    if (!await File(file).exists()) {
      missingFiles++;
      messageLog.add("File not found: $file");
    }
  }
  if (missingFiles > 0)
    return showToast("Missing ${pluralStr(missingFiles, "file")}");
  
  // get mod name
  var name = await textDialog(
    getGlobalContext(),
    title: "Mod name",
    initialValue: metadata.name,
    validator: (s) => s.isNotEmpty,
  );
  if (name == null) {
    showToast("Cancelled");
    return;
  }
  metadata.name = name;

  // get save path
  var savePath = await FilePicker.platform.saveFile(
    dialogTitle: "Save mod to zip",
    fileName: "$name.zip",
    allowedExtensions: ["zip"],
    type: FileType.custom,
  );
  if (savePath == null) {
    showToast("Cancelled");
    return;
  }
  
  await metadata.toFile(metadataPath);

  // copy all files to temp dir
  var tempDir = await Directory.systemTemp.createTemp("$name.zip_working_dir");
  var rootDir = dirname(waiPath);
  for (var file in changedFiles) {
    var relativePath = relative(file, from: rootDir);
    var tempPath = join(tempDir.path, relativePath);
    await Directory(dirname(tempPath)).create(recursive: true);
    await File(file).copy(tempPath);
  }

  // zip temp dir
  var zipEncoder = ZipFileEncoder();
  zipEncoder.create(savePath);
  await zipEncoder.addDirectory(Directory(tempDir.path), includeDirName: false);
  await zipEncoder.close();
  await tempDir.delete(recursive: true);

  showToast("Done");
}
