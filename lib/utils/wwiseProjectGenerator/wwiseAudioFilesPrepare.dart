
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';

import '../../background/wemFilesIndexer.dart';
import '../../fileTypeUtils/audio/bnkIO.dart';
import '../../fileTypeUtils/audio/wemToWavConverter.dart';
import '../utils.dart';
import 'wwiseIdGenerator.dart';
import 'wwiseProjectGenerator.dart';
import 'wwiseUtils.dart';

class WwiseAudioFile {
  final int id;
  final int? prefetchId;
  final String name;
  final String path;
  final bool isVoice;
  int _idsGenerated = 0;

  WwiseAudioFile(this.id, this.prefetchId, this.name, this.path, this.isVoice);

  int nextWemId(WwiseIdGenerator idGen) {
    if (_idsGenerated == 0) {
      _idsGenerated++;
      return id;
    }
    if (_idsGenerated == 1) {
      _idsGenerated++;
      if (prefetchId != null && prefetchId! > id)
        return prefetchId!;
    }
    return idGen.wemId(min: id + 1);
  }
}

Future<Map<int, WwiseAudioFile>> prepareWwiseAudioFiles(WwiseProjectGenerator project) async {
  Map<int, WwiseAudioFile> soundFiles = {};
  
  var bnk = project.bnk;
  var didx = bnk.chunks.whereType<BnkDidxChunk>().firstOrNull;
  var data = bnk.chunks.whereType<BnkDataChunk>().firstOrNull;
  if ((didx == null) != (data == null)) {
    project.log(WwiseLogSeverity.error, "BNK file has only one of DIDX and DATA chunks");
    throw Exception("BNK file has only one of DIDX and DATA chunks");
  }
  
  var internalWemFiles = {
    for (var (i, info) in (didx?.files ?? []).indexed)
      info.id: data?.wemFiles[i]
  };
  Set<int> usedWemIds = internalWemFiles.keys.toSet();
  Set<int> languageWemIds = {};
  Map<int, int> srcToFileIds = {};
  _collectWemIdStats(project, srcToFileIds, usedWemIds, languageWemIds);

  var sfxDir = join(project.projectPath, "Originals", "SFX");
  var langDir = project.language != "SFX" ? join(project.projectPath, "Originals", "Voices", project.language) : sfxDir;
  await Directory(sfxDir).create(recursive: true);
  await Directory(langDir).create(recursive: true);
  Future<Directory>? tmpDirLazy;
  try {
    await futuresWaitBatched(usedWemIds.map((id) async {
      var srcId = id;
      var fileId = srcToFileIds[srcId];
      var trueId = srcId;
      var isLangFile = languageWemIds.contains(srcId) || (fileId != null && languageWemIds.contains(fileId));
      var wavPath = join(isLangFile ? langDir : sfxDir, "${wwiseIdToStr(id)}.wav");
      int? prefetchId;
      String? wemPath;
      if (fileId != null) {
        wemPath = wemFilesLookup.lookup[fileId];
        if (wemPath == null)
          project.log(WwiseLogSeverity.warning, "WEM file ${wwiseIdToStr(fileId, alwaysIncludeId: true)} is prefetched, but original file is not indexed");
        else {
          trueId = fileId;
          prefetchId = srcId;
        }
      }
      wemPath ??= wemFilesLookup.lookup[srcId];
      if (wemPath == null) {
        var file = internalWemFiles[srcId];
        if (file == null) {
          project.log(WwiseLogSeverity.error, "WEM file ${wwiseIdToStr(srcId, alwaysIncludeId: true)} is not indexed or found in BNK file");
          return;
        }
        tmpDirLazy ??= Directory.systemTemp.createTemp("wwise_audio_files");
        var tmpDir = await tmpDirLazy!;
        wemPath = join(tmpDir.path, "$id.wem");
        await File(wemPath).writeAsBytes(file);
      }
      if (!await File(wavPath).exists())
        await wemToWav(wemPath, wavPath);
      var audioFile = WwiseAudioFile(trueId, prefetchId, wwiseIdToStr(id), wavPath, isLangFile);
      if (trueId != prefetchId && prefetchId != null) {
        soundFiles[trueId] = audioFile;
        soundFiles[prefetchId] = audioFile;
      } else if (!soundFiles.containsKey(id)) {
        soundFiles[id] = audioFile;
      }
    }), max(2, Platform.numberOfProcessors ~/ 2));
  } finally {
    await (await tmpDirLazy)?.delete(recursive: true);
  }
  return soundFiles;
}

void _collectWemIdStats(WwiseProjectGenerator project, Map<int, int> srcToFileId, Set<int> usedWemIds, Set<int> languageWemIds) {
  for (var sound in project.hircChunksByType<BnkSound>()) {
    var info = sound.bankData.mediaInformation;
    if (info.uFileID == 0)
      continue;
    usedWemIds.add(info.sourceID);
    var isVoice = sound.bankData.mediaInformation.uSourceBits & 1 != 0;
    if (isVoice)
      languageWemIds.add(info.uFileID);
    if (sound.bankData.streamType == 2) {
      usedWemIds.add(info.uFileID);
      srcToFileId[info.sourceID] = info.uFileID;
      if (isVoice)
        languageWemIds.add(info.uFileID);
    }
  }
  for (var track in project.hircChunksByType<BnkMusicTrack>()) {
    for (var source in track.sources) {
      var isVoice = source.uSourceBits & 1 != 0;
      usedWemIds.add(source.sourceID);
      if (isVoice)
        languageWemIds.add(source.fileID);
      if (source.streamType == 2) {
        usedWemIds.add(source.fileID);
        srcToFileId[source.sourceID] = source.fileID;
        if (isVoice)
          languageWemIds.add(source.fileID);
      }
    }
  }
}
