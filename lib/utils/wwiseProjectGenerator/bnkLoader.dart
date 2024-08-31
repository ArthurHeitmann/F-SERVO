
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart';

import '../../background/wemFilesIndexer.dart';
import '../../fileTypeUtils/audio/bnkIO.dart';
import '../../fileTypeUtils/audio/wemIdsToNames.dart';
import '../../fileTypeUtils/audio/wemToWavConverter.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../utils.dart';
import 'wwiseIdGenerator.dart';
import 'wwiseProjectGenerator.dart';
import 'wwiseUtils.dart';

class WwiseAudioFile {
  final int id;
  final int? prefetchId;
  final String name;
  final String path;
  final String language;
  final bool isVoice;
  int _idsGenerated = 0;

  WwiseAudioFile(this.id, this.prefetchId, this.name, this.path, this.language, this.isVoice);

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

class BnkContext<T> {
  final String path;
  final Set<String> names;
  final String language;
  final T value;

  BnkContext(this.path, this.names, this.language, this.value);

  BnkContext<U> cast<U>() => BnkContext(path, names, language, value as U);
}

class _AudioFileInfo {
  final int id;
  final int? prefetchId;
  final int streamType;
  final bool isVoice;

  _AudioFileInfo(this.id, this.prefetchId, this.streamType, this.isVoice);
}

Future<void> loadBnks(
  WwiseProjectGenerator project,
  List<String> bnkPaths,
  List<String> outBnkNames,
  List<BnkContext<BnkHircChunkBase>> outHircChunks,
  Map<int, BnkContext<BnkHircChunkBase>> outHircChunksById,
  Map<int, WwiseAudioFile> outSoundFiles
) async {
  Map<int, BnkContext<_AudioFileInfo>> usedAudioFiles = {};
  Map<int, BnkContext<({int index})>> inMemoryWemIds = {};
  Set<int> visitedBnkIds = {};

  for (var (i, bnkPath) in bnkPaths.indexed) {
    if (bnkPaths.length > 1)
      project.status.currentMsg.value = "Pre processing BNK file $i / ${bnkPaths.length} (${basename(bnkPath)})";

    var bnk = BnkFile.read(await ByteDataWrapper.fromFile(bnkPath));
    if (bnk.chunks.length == 1)
      continue;
    var header = bnk.chunks.whereType<BnkHeader>().first;
    var language = _languageIds[header.languageId] ?? "SFX";
    var bnkId = header.bnkId;
    var bnkName = wemIdsToNames[bnkId] ?? basename(bnkPath);
    outBnkNames.add(bnkName);
    if (visitedBnkIds.contains(bnkId)) {
      project.log(WwiseLogSeverity.warning, "Found ${basename(bnkPath)} more than once");
      continue;
    }
    visitedBnkIds.add(bnkId);
    
    var didx = bnk.chunks.whereType<BnkDidxChunk>().firstOrNull;
    var data = bnk.chunks.whereType<BnkDataChunk>().firstOrNull;
    if ((didx == null) != (data == null)) {
      throw Exception("BNK file has only one of DIDX and DATA chunks");
    }
    // index in memory WEM files
    if (didx != null && data != null) {
      for (var (i, info) in didx.files.indexed) {
        var wemId = info.id;
        inMemoryWemIds[wemId] = BnkContext(bnkPath, {}, language, (index: i));
      }
    }

    // collect all hirc chunks and used audio files
    var hirc = bnk.chunks.whereType<BnkHircChunk>().firstOrNull;
    if (hirc != null) {
      for (var chunk in hirc.chunks) {
        var existing = outHircChunksById[chunk.uid];
        if (existing != null) {
          existing.names.add(bnkName);
          if (existing.value.size != chunk.size)
            project.log(WwiseLogSeverity.warning, "Found chunk ${chunk.uid} (${chunk.size} B) (${basename(bnkPath)}) more than once. Using largest chunk");
          if (existing.language != language)
            project.log(WwiseLogSeverity.warning, "Found chunk ${chunk.uid} (${basename(bnkPath)}) with different languages ${existing.language} and $language");
          if (chunk.size <= existing.value.size)
            continue;
        }
        var hircContext = existing ?? BnkContext(bnkPath, {bnkName}, language, chunk);
        outHircChunksById[chunk.uid] = hircContext;

        // collect all used audio files
        List<({int sourceId, int fileId, int streamType, bool isVoice})> sources = [];
        if (chunk is BnkSound) {
          sources.add((
            sourceId: chunk.bankData.mediaInformation.sourceID,
            fileId: chunk.bankData.mediaInformation.uFileID,
            streamType: chunk.bankData.streamType,
            isVoice: chunk.bankData.mediaInformation.uSourceBits & 1 != 0
          ));
        }
        else if (chunk is BnkMusicTrack) {
          for (var src in chunk.sources) {
            sources.add((
              sourceId: src.sourceID,
              fileId: src.fileID,
              streamType: src.streamType,
              isVoice: src.uSourceBits & 1 != 0
            ));
          }
        }
        for (var src in sources) {
          if (src.fileId == 0)
            continue;
          if (src.streamType == 0) {
            usedAudioFiles[src.sourceId] = BnkContext(bnkPath, {}, language, _AudioFileInfo(src.sourceId, null, src.streamType, src.isVoice));
          } else if (src.streamType == 1) {
            usedAudioFiles[src.fileId] = BnkContext(bnkPath, {}, language, _AudioFileInfo(src.fileId, null, src.streamType, src.isVoice));
          } else if (src.streamType == 2) {
            usedAudioFiles[src.fileId] = BnkContext(bnkPath, {}, language, _AudioFileInfo(src.fileId, src.sourceId, src.streamType, src.isVoice));
          } else {
            project.log(WwiseLogSeverity.warning, "Unknown stream type ${src.streamType}");
          }
        }
      }
    }
  }

  outHircChunks.addAll(outHircChunksById.values);

  // add all used audio files to project
  if (project.options.wems)
    await _loadWems(usedAudioFiles, project, inMemoryWemIds, outSoundFiles);
}

Future<void> _loadWems(Map<int, BnkContext<_AudioFileInfo>> usedAudioFiles, WwiseProjectGenerator project, Map<int, BnkContext<({int index})>> inMemoryWemIds, Map<int, WwiseAudioFile> outSoundFiles) async {
  var usedLanguages = usedAudioFiles.values.map((f) => f.language).toSet();
  Map<String, String> langPaths = {};
  for (var language in usedLanguages) {
    String langPath;
    if (language == "SFX")
      langPath = join(project.projectPath, "Originals", "SFX");
    else
      langPath = join(project.projectPath, "Originals", "Voices", language);
    await Directory(langPath).create(recursive: true);
    langPaths[language] = langPath;
  }
  var tempDir = await Directory.systemTemp.createTemp("wem_conversion");
  var parallel = max(2, Platform.numberOfProcessors ~/ 2);
  var bnkCache = _BnkCache(parallel + 1);
  var processed = 0;
  try {
    await futuresWaitBatched(usedAudioFiles.values.map((audioContext) async {
      processed++;
      project.status.currentMsg.value = "Processing WEM files $processed / ${usedAudioFiles.length}";
      // get wem path
      String? wemPath;
      Uint8List? wemBytes;
      var streamType = audioContext.value.streamType;
      if (streamType == 0) {
        var audioInfo = inMemoryWemIds[audioContext.value.id];
        if (audioInfo == null) {
          project.log(WwiseLogSeverity.warning, "WEM file ${wwiseIdToStr(audioContext.value.id, alwaysIncludeId: true)} is not found in any BNK file");
          return;
        }
        var bnkFiles = await bnkCache.get(audioInfo.path);
        var index = audioInfo.value.index;
        wemBytes = bnkFiles[index];
      }
      else if (streamType == 1) {
        wemPath = wemFilesLookup.lookup[audioContext.value.id];
        if (wemPath == null) {
          project.log(WwiseLogSeverity.warning, "WEM file ${wwiseIdToStr(audioContext.value.id, alwaysIncludeId: true)} is not indexed");
          return;
        }
      }
      else if (streamType == 2) {
        wemPath = wemFilesLookup.lookup[audioContext.value.id];
        if (wemPath == null) {
          var audioInfo = inMemoryWemIds[audioContext.value.prefetchId!];
          if (audioInfo == null) {
            project.log(WwiseLogSeverity.warning, "WEM file ${wwiseIdToStr(audioContext.value.id, alwaysIncludeId: true)} is not indexed and prefetch file ${wwiseIdToStr(audioContext.value.prefetchId!, alwaysIncludeId: true)} is not found in any BNK file");
            return;
          }
          project.log(WwiseLogSeverity.warning, "WEM file ${wwiseIdToStr(audioContext.value.id, alwaysIncludeId: true)} is not indexed, using prefetch file ${wwiseIdToStr(audioContext.value.prefetchId!, alwaysIncludeId: true)}");
          var bnkFiles = await bnkCache.get(audioInfo.path);
          var index = audioInfo.value.index;
          wemBytes = bnkFiles[index];
        }
      }
      if (wemPath == null) {
        wemPath = join(tempDir.path, "${audioContext.value.id}.wem");
        await File(wemPath).writeAsBytes(wemBytes!);
      }
  
      // save to project as WAV
      var langFolder = langPaths[audioContext.language]!;
      var wavPath = join(langFolder, "${wwiseIdToStr(audioContext.value.id)}.wav");
      if (!await File(wavPath).exists())
        await wemToWav(wemPath, wavPath);
      
      var audioFile = WwiseAudioFile(audioContext.value.id, audioContext.value.prefetchId, wwiseIdToStr(audioContext.value.id), wavPath, audioContext.language, audioContext.value.isVoice);
      outSoundFiles[audioContext.value.id] = audioFile;
      if (audioContext.value.prefetchId != null)
        outSoundFiles[audioContext.value.prefetchId!] = audioFile;
    }), parallel);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

class _BnkCacheFile {
  int lastUsed;
  final String path;
  final List<Uint8List> wems;

  _BnkCacheFile(this.lastUsed, this.path, this.wems);
}

class _BnkCache {
  final List<_BnkCacheFile> _files = [];
  final int maxBnks;

  _BnkCache(this.maxBnks);

  Future<List<Uint8List>> get(String path) async {
    var bnk = _get(path);
    if (bnk != null) {
      bnk.lastUsed = _now();
      return bnk.wems;
    }
    _makeSpace();
    var bnkFile = BnkFile.read(await ByteDataWrapper.fromFile(path));
    var data = bnkFile.chunks.whereType<BnkDataChunk>().firstOrNull;
    var wems = data?.wemFiles ?? [];
    var cacheFile = _BnkCacheFile(_now(), path, wems);
    _files.add(cacheFile);
    return wems;
  }

  _BnkCacheFile? _get(String path) {
    return _files
      .where((b) => b.path == path)
      .firstOrNull;
  }

  int _now() => DateTime.now().microsecondsSinceEpoch;

  void _makeSpace() {
    if (_files.length < maxBnks)
      return;
    int oldestUsed = _now();
    int oldestIndex = 0;
    for (var (i, b) in _files.indexed) {
      if (b.lastUsed < oldestUsed) {
        oldestUsed = b.lastUsed;
        oldestIndex = i;
      }
    }
    _files.removeAt(oldestIndex);
  }
}

const _languageIds = {
  0x00: "SFX",
  0x01: "Arabic",
  0x02: "Bulgarian",
  0x03: "Chinese(HK)",
  0x04: "Chinese(PRC)",
  0x05: "Chinese(Taiwan)",
  0x06: "Czech",
  0x07: "Danish",
  0x08: "Dutch",
  0x09: "English(Australia)",
  0x0A: "English(India)",
  0x0B: "English(UK)",
  0x0C: "English(US)",
  0x0D: "Finnish",
  0x0E: "French(Canada)",
  0x0F: "French(France)",
  0x10: "German",
  0x11: "Greek",
  0x12: "Hebrew",
  0x13: "Hungarian",
  0x14: "Indonesian",
  0x15: "Italian",
  0x16: "Japanese",
  0x17: "Korean",
  0x18: "Latin",
  0x19: "Norwegian",
  0x1A: "Polish",
  0x1B: "Portuguese(Brazil)",
  0x1C: "Portuguese(Portugal)",
  0x1D: "Romanian",
  0x1E: "Russian",
  0x1F: "Slovenian",
  0x20: "Spanish(Mexico)",
  0x21: "Spanish(Spain)",
  0x22: "Spanish(US)",
  0x23: "Swedish",
  0x24: "Turkish",
  0x25: "Ukrainian",
  0x26: "Vietnamese",
};
