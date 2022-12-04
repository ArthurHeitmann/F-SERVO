
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../fileTypeUtils/audio/riffParser.dart';

const audioFilesDir = r"D:\delete\mods\na\NieR-Audio-Tools\waiExtracted";
const filter = "vo_core_";

// Set<String> wspsWithoutAudioOffsets = {};
List<String> wemsWithoutAudioOffsets = [];
// Set<String> wspsWithAudioOffsets = {};
List<String> wemsWithAudioOffsets = [];

int i = 0;
Future<void> processWem(String wemPath) async {
  var riff = await RiffFile.fromFile(wemPath);
  var format = riff.format;
  if (format is! WemFormatChunk) {
    print("WEM file $wemPath has no WEM format chunk");
    return;
  }
  if (format.setupPacketOffset == 0)
    // wspsWithoutAudioOffsets.add(wspDir);
    wemsWithoutAudioOffsets.add(wemPath);
  else
    // wspsWithAudioOffsets.add(wspDir);
    wemsWithAudioOffsets.add(wemPath);
  
  // stdout.write("\r${++i}");
}

void main(List<String> args) async {
  var wemFiles = await Directory(audioFilesDir)
    .list(recursive: true)
    .where((e) => e.path.endsWith(".wem"))
    .where((e) => e.parent.path.contains(filter))
    .toList();
  // await Future.wait(wemFiles.map((e) => processWem(e.path)));
  for (int i = 0; i < wemFiles.length; i += 25) {
    var batch = wemFiles.sublist(i, min(i + 25, wemFiles.length));
    await Future.wait(batch.map((e) => processWem(e.path)));
  }
  // print("WSPs without audio offsets: ${wspsWithoutAudioOffsets.length}");
  // print(const JsonEncoder.withIndent("\t").convert(wspsWithoutAudioOffsets.toList()));
  // print("WSPs with audio offsets: ${wspsWithAudioOffsets.length}");
  // print(const JsonEncoder.withIndent("\t").convert(wspsWithAudioOffsets.toList()));
  print("WEMs without audio offsets: ${wemsWithoutAudioOffsets.length}");
  print(const JsonEncoder.withIndent("\t").convert(wemsWithoutAudioOffsets));
  print("WEMs with audio offsets: ${wemsWithAudioOffsets.length}");
  print(const JsonEncoder.withIndent("\t").convert(wemsWithAudioOffsets));
}
