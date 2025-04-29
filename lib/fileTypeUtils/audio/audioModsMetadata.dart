
import 'dart:convert';

import 'package:mutex/mutex.dart';

import '../../utils/version.dart';
import '../../fileSystem/FileSystem.dart';


class AudioModChunkInfo {
  final int id;
  final String? name;
  final int? timestamp;

  const AudioModChunkInfo(this.id, { this.name, this.timestamp });

  AudioModChunkInfo.fromJSON(Map<String, dynamic> json) :
    id = json["id"],
    name = json["name"],
    timestamp = json["date"];
  
  Map<String, dynamic> toJSON() => {
    "id": id,
    if (name != null)
      "name": name,
    if (timestamp != null)
      "date": timestamp,
  };
}

class AudioModsMetadata {
  static final Mutex _mutex = Mutex();
  static const Version currentVersion = Version(1, 1, 0);
  final Version version;
  String? name;
  final Map<int, AudioModChunkInfo> moddedWaiChunks;
  final Map<int, AudioModChunkInfo> moddedWaiEventChunks;
  final Map<int, AudioModChunkInfo> moddedBnkChunks;

  AudioModsMetadata(this.version, this.name, this.moddedWaiChunks, this.moddedWaiEventChunks, this.moddedBnkChunks);

  AudioModsMetadata.fromJSON(Map<String, dynamic> json) :
    version = Version.parse(json["version"] ?? "") ?? currentVersion,
    name = json["name"],
    moddedWaiChunks = {
      for (var e in (json["moddedWaiChunks"] as Map).values)
        e["id"] : AudioModChunkInfo.fromJSON(e)
    },
    moddedWaiEventChunks = json.containsKey("moddedWaiEventChunks") ? {
      for (var e in (json["moddedWaiEventChunks"] as Map).values)
        e["id"] : AudioModChunkInfo.fromJSON(e)
    } : {},
    moddedBnkChunks = {
      for (var e in (json["moddedBnkChunks"] as Map).values)
        e["id"] : AudioModChunkInfo.fromJSON(e)
    };
  
  static Future<AudioModsMetadata> fromFile(String path) async {
    if (!await FS.i.existsFile(path))
      return AudioModsMetadata(currentVersion, null, {}, {}, {});
    var json = jsonDecode(await FS.i.readAsString(path));
    return AudioModsMetadata.fromJSON(json);
  }
  
  Map<String, dynamic> toJSON() => {
    "version": version.toString(),
    "name": name,
    "moddedWaiChunks": {
      for (var e in moddedWaiChunks.values)
        e.id.toString() : e.toJSON()
    },
    "moddedWaiEventChunks": {
      for (var e in moddedWaiEventChunks.values)
        e.id.toString() : e.toJSON()
    },
    "moddedBnkChunks": {
      for (var e in moddedBnkChunks.values)
        e.id.toString() : e.toJSON()
    },
  };

  Future<void> toFile(String path) async {
    var encoder = const JsonEncoder.withIndent("\t");
    await FS.i.writeAsString(path, encoder.convert(toJSON()));
  }

  static Future<void> lock() async => await _mutex.acquire();
  static void unlock() => _mutex.release();
}

const String audioModsMetadataFileName = "audioModsMetadata.json";
