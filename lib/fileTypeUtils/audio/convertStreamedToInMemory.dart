
import 'dart:typed_data';

import 'package:path/path.dart';

import '../../background/wemFilesIndexer.dart';
import '../../main.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../../widgets/misc/fileSelectionDialog.dart';
import '../utils/ByteDataWrapper.dart';
import 'bnkExtractor.dart';
import 'bnkIO.dart';
import 'wemIdsToNames.dart';
import '../../fileSystem/FileSystem.dart';

Future<void> convertStreamedToInMemory(String bnkPath, int wemId) async {
  try {
    isLoadingStatus.pushIsLoading();
    await _convertStreamedToInMemory(bnkPath, wemId);
  } catch (e, s) {
    messageLog.add("$e\n$s");
    messageLog.add("Failed to convert WEM $wemId to in-memory: $e");
    showToast("Failed to convert WEM $wemId to in-memory");
  } finally {
    isLoadingStatus.popIsLoading();
  }
}

Future<void> _convertStreamedToInMemory(String bnkPath, int wemId) async {
  var bnk = BnkFile.read(await ByteDataWrapper.fromFile(bnkPath));
  var didx = bnk.chunks.whereType<BnkDidxChunk>().firstOrNull;
  var data = bnk.chunks.whereType<BnkDataChunk>().firstOrNull;
  didx ??= BnkDidxChunk("DIDX", 0, []);
  data ??= BnkDataChunk("DATA", 0, []);
  var hirc = bnk.chunks.whereType<BnkHircChunk>().first;

  var (prefetchId: prefetchId, sourceId: sourceId) = _getIdConfig(hirc.chunks, wemId);
  if (sourceId == null)
    return;
  var newId = prefetchId ?? sourceId;
  int wemIndex = didx.files.indexWhere((element) => element.id == newId);
  Uint8List? existingWemData;
  if (wemIndex != -1) {
    didx.files.removeAt(wemIndex);
    existingWemData = data.wemFiles.removeAt(wemIndex);
  }
  else {
    for (var i = 0; i < didx.files.length; i++) {
      if (newId <= didx.files[i].id) {
        wemIndex = i;
        break;
      }
    }
    if (wemIndex == -1)
      wemIndex = didx.files.length;
  }

  var wemData = await _getWemData(sourceId, existingWemData);
  if (wemData == null)
    return;
  data.wemFiles.insert(wemIndex, wemData);
  didx.files.insert(wemIndex, BnkWemFileInfo(newId, 0, wemData.length));
  data.updateOffsets(didx);
  didx.updateChunkSize();
  data.updateChunkSize();
  
  _updateUsages(hirc.chunks, prefetchId, sourceId, newId, wemData.length);

  var extractDir = join(dirname(bnkPath), "${basename(bnkPath)}_extracted");
  await for (var file in FS.i.listFiles(extractDir)) {
    if (file.endsWith(".wem"))
      await FS.i.delete(file);
  }
  await extractBnkWems(bnk, extractDir);

  await backupFile(bnkPath);
  var bnkBytes = ByteDataWrapper.allocate(bnk.calculateSize());
  bnk.write(bnkBytes);
  await bnkBytes.save(bnkPath);

  showToast("WEM $wemId converted to in-memory");
}

({int? prefetchId, int? sourceId}) _getIdConfig(List<BnkHircChunkBase> chunks, int fileId) {
  Set<int> prefetchIds = {};
  Set<int> sourceIds = {};

  for (var chunk in chunks) {
    List<({int srcId, int fileId, int streamType})> sources = [];
    if (chunk is BnkSound) {
      var bankData = chunk.bankData;
      sources.add((srcId: bankData.mediaInformation.sourceID, fileId: bankData.mediaInformation.uFileID, streamType: bankData.streamType));
    } else if (chunk is BnkMusicTrack) {
      for (var src in chunk.sources)
        sources.add((srcId: src.sourceID, fileId: src.fileID, streamType: src.streamType));
    }
    for (var src in sources) {
      if (src.srcId != fileId && src.fileId != fileId)
        continue;
      if (src.streamType == 1)
        sourceIds.add(src.srcId);
      else if (src.streamType == 2) {
        prefetchIds.add(src.srcId);
        sourceIds.add(src.fileId);
      }
    }
  }

  if (prefetchIds.length > 1 || sourceIds.length != 1) {
    messageLog.add("Invalid prefetch/source id config [${prefetchIds.join(", ")}] / [${sourceIds.join(", ")}]");
    showToast("Failed to determine prefetch/source id config");
    return (prefetchId: null, sourceId: null);
  }

  return (prefetchId: prefetchIds.firstOrNull, sourceId: sourceIds.first);
}

Future<Uint8List?> _getWemData(int sourceId, Uint8List? existingWemData) async {
  var wemPath = wemFilesLookup.lookup[sourceId];
  if (wemPath == null) {
    var allowFallback = existingWemData != null;
    wemPath = await fileSelectionDialog(
      getGlobalContext(),
      selectionType: SelectionType.file,
      title: "Select source WEM",
      body:
        // ignore: prefer_interpolation_to_compose_strings
        "Select original WEM file for \n\"[$sourceId]" +
        (wemIdsToNames.containsKey(sourceId) ? " ${wemIdsToNames[sourceId]}\"" : "\"") +
        (allowFallback ? " \nor cancel to use the short WEM" : ""),
    );
    if (wemPath == null) {
      if (allowFallback)
        return existingWemData;
      return null;
    }
  }
  var data = await FS.i.read(wemPath);
  return Uint8List.fromList(data);
}

void _updateUsages(List<BnkHircChunkBase> chunks, int? prefetchId, int sourceId, int newId, int size) {
  for (var chunk in chunks) {
    if (chunk is BnkSound) {
      var data = chunk.bankData;
      if (data.mediaInformation.sourceID == sourceId || data.mediaInformation.uFileID == sourceId) {
        data.streamType = 0;
        data.mediaInformation.sourceID = newId;
        data.mediaInformation.uFileID = newId;
        data.mediaInformation.fileOffset = 0;
        data.mediaInformation.uInMemoryMediaSize = size;
      }
    } else if (chunk is BnkMusicTrack) {
      for (var (i, src) in chunk.sources.indexed) {
        if (src.sourceID == sourceId || src.fileID == sourceId) {
          src.streamType = 0;
          src.sourceID = newId;
          src.fileID = newId;
          src.uFileOffset = 0;
          src.uInMemorySize = size;
          chunk.playlists[i].sourceID = newId;
        }
      }
    }
  }
}
