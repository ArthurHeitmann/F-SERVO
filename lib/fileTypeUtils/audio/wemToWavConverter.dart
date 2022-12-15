
import 'dart:io';

import 'package:path/path.dart';

import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';

Map<String, String> _tmpExtractDirs = {};

Future<String> wemToWavTmp(String wemPath, [String folderPrefix = ""]) async {
  if (!_tmpExtractDirs.containsKey(folderPrefix))
    _tmpExtractDirs[folderPrefix] = (await Directory.systemTemp.createTemp("wemToWav")).path;
  var tmpDir = _tmpExtractDirs[folderPrefix]!;
  var tempWavPath = join(tmpDir, "${basenameWithoutExtension(wemPath)}_${randomId().toRadixString(36)}.wav");
  await wemToWav(wemPath, tempWavPath);
  return tempWavPath;
}

Future<void> wemToWav(String wemPath, String wavPath) async {
  var vgmStreamPath = join(assetsDir!, "bins", "vgmStream", "vgmStream.exe");
  var process = await Process.run(vgmStreamPath, ["-o", wavPath, wemPath]);
  if (process.exitCode != 0) {
    print("stdout: ${process.stdout}");
    print("stderr: ${process.stderr}");
    throw Exception("WemToWav: Process exited with code ${process.exitCode}");
  }
  if (!await File(wavPath).exists()) {
    print("stdout: ${process.stdout}");
    print("stderr: ${process.stderr}");
    throw Exception("WemToWav: File not found ($wavPath)");
  }
}
