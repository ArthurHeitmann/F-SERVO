
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/utils.dart';
import '../utils/ByteDataWrapper.dart';
import 'audioModsMetadata.dart';
import 'bnkIO.dart';
import 'waiIO.dart';


Future<void> installMod(String waiPath) async {
  var selectedFiles = await FilePicker.platform.pickFiles(
    dialogTitle: "Select mod zip",
    allowedExtensions: ["zip"],
    type: FileType.custom,
    allowMultiple: false,
  );
  if (selectedFiles == null || selectedFiles.files.isEmpty)
    return;
  var zipPath = selectedFiles.files.first.path!;

  var tmpDir = await Directory.systemTemp.createTemp("nier_music_mod_installer");
  List<String> changedFiles = [];
  try {
    var fs = InputFileStream(zipPath);
    var archive = ZipDecoder().decodeBuffer(fs);
    extractArchiveToDisk(archive, tmpDir.path);
    fs.close();

    var metadataFile = join(dirname(waiPath), audioModsMetadataFileName);
    var metadata = await AudioModsMetadata.fromFile(metadataFile);

    var modMetadataFile = join(tmpDir.path, audioModsMetadataFileName);
    if (!await File(modMetadataFile).exists())
      throw Exception("No metadata file found in archive");
    
    var modMetadata = await AudioModsMetadata.fromFile(modMetadataFile);

    if (modMetadata.moddedBnkChunks.isEmpty && modMetadata.moddedWaiChunks.isEmpty)
      throw Exception("No modded files found in archive");

    // apply patches
    await _patchWaiAndWspsAndWems(modMetadata.moddedWaiChunks, tmpDir.path, waiPath, changedFiles);
    await _patchWaiEvents(metadata.moddedWaiEventChunks, tmpDir.path, waiPath, changedFiles);
    await _patchBgmBnk(modMetadata.moddedBnkChunks, tmpDir.path, waiPath, changedFiles);
    
    // update metadata
    metadata.moddedWaiChunks.addAll(modMetadata.moddedWaiChunks);
    metadata.moddedWaiEventChunks.addAll(modMetadata.moddedWaiEventChunks);
    metadata.moddedBnkChunks.addAll(modMetadata.moddedBnkChunks);
    metadata.name = modMetadata.name;
    await metadata.toFile(metadataFile);

    // delete original backup files
    for (var file in changedFiles) {
      var originalPath = "$file.original";
      await File(originalPath).delete();
    }

    showToast("Mod installed successfully :)");
    messageLog.add("Mod installed successfully :)");
  } catch (e) {
    // restore original files
    for (var file in changedFiles) {
      var originalPath = "$file.original";
      if (!await File(originalPath).exists()) {
        print("Failed to restore original file $file");
        continue;
      }
      if (await File(file).exists())
        await File(file).delete();
      await File(originalPath).rename(file);
      print("Restored original file $file");
    }

    showToast("Failed to install mod :/");
    rethrow;
  } finally {
    await tmpDir.delete(recursive: true);
  }
}

Future<void> _patchWaiAndWspsAndWems(Map<int, AudioModChunkInfo> moddedWaiChunks, String tmpDir, String waiPath, List<String> changedFiles) async {
  if (moddedWaiChunks.isEmpty)
    return;
  var newWaiPath = join(tmpDir, "WwiseStreamInfo.wai");
  var originalWai = WaiFile.read(await ByteDataWrapper.fromFile(waiPath));
  var newWai = WaiFile.read(await ByteDataWrapper.fromFile(newWaiPath));

  Map<WspId, List<int>> wemIdsByWsp = {};
  for (var wemId in moddedWaiChunks.keys) {
    var wem = newWai.getWemFromId(wemId);
    var wspKey = WspId.fromWem(wem, newWai);
    if (!wemIdsByWsp.containsKey(wspKey))
      wemIdsByWsp[wspKey] = [];
    wemIdsByWsp[wspKey]!.add(wemId);
  }

  // Patch WEM chunks in WAI
  // first update sizes
  for (var wemId in moddedWaiChunks.keys) {
    var newSize = newWai.getWemFromId(wemId).wemEntrySize;
    originalWai.getWemFromId(wemId).wemEntrySize = newSize;
  }
  // then update WEM offsets in WSP
  Map<int, WemStruct> originalWemsById = {};
  for (var wspId in wemIdsByWsp.keys) {
    var allWspWems = originalWai.wemStructs
      .where((wem) => wspId.isWemInWsp(wem, originalWai))
      .toList();
    allWspWems.sort((a, b) => a.wemOffset.compareTo(b.wemOffset));
    for (var wem in allWspWems)
      originalWemsById[wem.wemID] = wem.copy();
    int offset = 0;
    for (WemStruct wemStruct in allWspWems) {
      wemStruct.wemOffset = offset;
      offset += wemStruct.wemEntrySize;
      offset = (offset + 2047) & ~2047;
    }
  }

  // make new WSPs and extract WEMs
  var prefs = PreferencesData();
  var waiExtractDir = prefs.waiExtractDir?.value;
  if (waiExtractDir == null || waiExtractDir.isEmpty) {
    showToast("Please set WAI extract directory in settings");
    throw Exception("WAI extract directory not set");
  }
  for (var wspId in wemIdsByWsp.keys) {
    // wsp might be in sub directory
    var wspWems = originalWai.wemStructs
      .where((wem) => wspId.isWemInWsp(wem, originalWai))
      .toList();
    wspWems.sort((a, b) => a.wemOffset.compareTo(b.wemOffset));
    var firstWemInWsp = wspWems.first;
    var wspDir = wspId.folder;
    var wspSaveDir = join(dirname(waiPath), "stream");
    var modWspDir = tmpDir;
    var wemExtractDir = waiExtractDir;
    if (wspDir != null) {
      wspSaveDir = join(wspSaveDir, wspDir);
      modWspDir = join(modWspDir, wspDir);
      wemExtractDir = join(wemExtractDir, wspDir);
    }
    var wspName = firstWemInWsp.wemToWspName(newWai.wspNames);

    var originalWspPath = join(wspSaveDir, wspName);
    var modWspPath = join(modWspDir, "stream", wspName);
    var tmpNewWspPath = join(tmpDir, wspName);
    wemExtractDir = join(wemExtractDir, wspName);
    await File(originalWspPath).copy(tmpNewWspPath);

    // open files
    var originalWsp = await File(originalWspPath).open();
    var modWsp = await File(modWspPath).open();
    var newWsp = await File(tmpNewWspPath).open(mode: FileMode.writeOnly);

    try {
      // extract WEMs
      await _extractWems(modWsp, newWai, wemIdsByWsp[wspId]!, wspWems, wemExtractDir, changedFiles);

      // place WEMs in new WSP
      for (var wem in wspWems) {
        // determine which WSP to read from (original or mod)
        RandomAccessFile srcWsp;
        int srcOffset;
        if (moddedWaiChunks.containsKey(wem.wemID)) {
          srcWsp = modWsp;
          srcOffset = newWai.getWemFromId(wem.wemID).wemOffset;
        } else {
          srcWsp = originalWsp;
          srcOffset = originalWemsById[wem.wemID]!.wemOffset;
        }
        // read WEM from WSP
        await srcWsp.setPosition(srcOffset);
        var wemData = await srcWsp.read(wem.wemEntrySize);
        // write WEM to new WSP
        await newWsp.setPosition(wem.wemOffset);
        await newWsp.writeFrom(wemData);
      }
      var endPos = await newWsp.position();
      var alignBytes = List.filled(2048 - endPos % 2048, 0);
      await newWsp.writeFrom(alignBytes);
    } finally {
      // close files
      await originalWsp.close();
      await modWsp.close();
      await newWsp.close();
    }

    // backup original WSP
    await backupFile(originalWspPath);
    var originalBackupPath = "$originalWspPath.original";
    await File(originalWspPath).copy(originalBackupPath);
    changedFiles.add(originalWspPath);
    // replace original WSP with new WSP
    await File(originalWspPath).delete();
    await File(tmpNewWspPath).copy(originalWspPath);
  }

  // backup original WAI
  await backupFile(waiPath);
  var originalBackupPath = "$waiPath.original";
  await File(waiPath).copy(originalBackupPath);
  changedFiles.add(waiPath);
  // save new WAI
  var newWaiBytes = ByteDataWrapper.allocate(originalWai.size);
  originalWai.write(newWaiBytes);
  await newWaiBytes.save(waiPath);
}

Future<void> _patchWaiEvents(Map<int, AudioModChunkInfo> moddedWaiEvents, String tmpDir, String waiStreamPath, List<String> changedFiles) async {
  if (moddedWaiEvents.isEmpty)
    return;
  
  var waiPath = join(dirname(waiStreamPath), "WwiseInfo.wai");
  var newWaiPath = join(tmpDir, "WwiseInfo.wai");
  var originalWai = WaiFile.readEvents(await ByteDataWrapper.fromFile(waiPath));
  var newWai = WaiFile.readEvents(await ByteDataWrapper.fromFile(newWaiPath));

  for (int eventId in moddedWaiEvents.keys) {
    var event = newWai.getEventFromId(eventId);
    int insertIndex = originalWai.getEventInsertIndex(eventId);
    originalWai.waiEventStructs.insert(insertIndex, event);
  }
  originalWai.header.structCount = originalWai.waiEventStructs.length;

  // backup original WAI
  await backupFile(waiPath);
  var originalBackupPath = "$waiPath.original";
  await File(waiPath).copy(originalBackupPath);
  changedFiles.add(waiPath);
  // save new WAI
  var newWaiBytes = ByteDataWrapper.allocate(newWai.size);
  newWai.write(newWaiBytes);
  await newWaiBytes.save(waiPath);
}

Future<void> _extractWems(RandomAccessFile wsp, WaiFile wai, List<int> moddedWemIds, List<WemStruct> allWspWems, String extractDir, List<String> changedFiles) async {
  for (var wemId in moddedWemIds) {
    var wemIndex = allWspWems.indexWhere((wem) => wem.wemID == wemId);
    var wem = allWspWems[wemIndex];
    var wemPath = join(extractDir, wem.toFileName(wemIndex));

    // backup original WEM
    await backupFile(wemPath);
    var originalBackupPath = "$wemPath.original";
    await File(wemPath).copy(originalBackupPath);
    changedFiles.add(wemPath);

    await wsp.setPosition(wem.wemOffset);
    var wemData = await wsp.read(wem.wemEntrySize);
    await File(wemPath).writeAsBytes(wemData);
  }
}

Future<void> _patchBgmBnk(Map<int, AudioModChunkInfo> moddedBnkChunks, String tmpDir, String waiPath, List<String> changedFiles) async {
  if (moddedBnkChunks.isEmpty)
    return;
  
  // open files
  var originalBnkPath = join(dirname(waiPath), "bgm", "BGM.bnk");
  var newBnkPath = join(tmpDir, "bgm", "BGM.bnk");
  var originalBnkBytes = await ByteDataWrapper.fromFile(originalBnkPath);
  var originalBnk = BnkFile.read(originalBnkBytes);
  var newBnk = BnkFile.read(await ByteDataWrapper.fromFile(newBnkPath));
  var originalHirc = originalBnk.chunks.whereType<BnkHircChunk>().first.chunks;
  var newHirc = newBnk.chunks.whereType<BnkHircChunk>().first.chunks;
  var originalUidToIndex = {
    for (var i = 0; i < originalHirc.length; i++)
      originalHirc[i].uid: i
  };
  var newUidToIndex = {
    for (var i = 0; i < newHirc.length; i++)
        newHirc[i].uid: i
  };

  // patch BNK HIRC chunks
  for (var chunkId in moddedBnkChunks.keys) {
    if (!originalUidToIndex.containsKey(chunkId) || !newUidToIndex.containsKey(chunkId))
      throw Exception("Could not find chunk with ID $chunkId in BGM.bnk");
    var newChunk = newHirc[newUidToIndex[chunkId]!];
    var originalIndex = originalUidToIndex[chunkId]!;
    originalHirc[originalIndex] = newChunk;
  }

  // calculate new HIRC chunk size
  var hircChunk = originalBnk.chunks.whereType<BnkHircChunk>().first;
  var prevSize = hircChunk.chunkSize;
  var newSize = hircChunk.chunks.fold<int>(0, (prev, chunk) => prev + chunk.size + 5);
  newSize += 4; // children count
  hircChunk.chunkSize = newSize;
  var sizeDiff = newSize - prevSize;

  // backup original BNK
  await backupFile(originalBnkPath);
  var originalBackupPath = "$originalBnkPath.original";
  await File(originalBnkPath).copy(originalBackupPath);
  changedFiles.add(originalBnkPath);
  // save new BNK
  var newBnkBytes = ByteDataWrapper.allocate(originalBnkBytes.length + sizeDiff);
  originalBnk.write(newBnkBytes);
  await newBnkBytes.save(originalBnkPath);
}
