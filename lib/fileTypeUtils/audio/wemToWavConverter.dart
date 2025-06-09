

import 'dart:io';

import 'package:path/path.dart';

import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../../fileSystem/FileSystem.dart';
import '../../web/webImports.dart';

Map<String, String> _tmpExtractDirs = {};

Future<String> wemToWavTmp(String wemPath, [String folderPrefix = ""]) async {
  if (!_tmpExtractDirs.containsKey(folderPrefix))
    _tmpExtractDirs[folderPrefix] = (await FS.i.createTempDirectory("wemToWav"));
  var tmpDir = _tmpExtractDirs[folderPrefix]!;
  var tempWavPath = join(tmpDir, "${basenameWithoutExtension(wemPath)}_${randomId().toRadixString(36)}.wav");
  await wemToWav(wemPath, tempWavPath);
  return tempWavPath;
}

Future<void> wemToWav(String wemPath, String wavPath) async {
  if (isDesktop) {
    await _wemToWavDesktop(wemPath, wavPath);
  } else if (isWeb) {
    await _wemToWavWeb(wemPath, wavPath);
  } else {
    throw Exception("WemToWav: Unsupported platform");
  }
}

Future<void> _wemToWavDesktop(String wemPath, String wavPath) async {
  var vgmStreamPath = join(assetsDir!, "bins", "vgmStream", "vgmStream.exe");
  var process = await Process.run(vgmStreamPath, ["-o", wavPath, wemPath]);
  if (process.exitCode != 0) {
    print("stdout: ${process.stdout}");
    print("stderr: ${process.stderr}");
    throw Exception("WemToWav: Process exited with code ${process.exitCode}");
  }
  if (!await FS.i.existsFile(wavPath)) {
    print("stdout: ${process.stdout}");
    print("stderr: ${process.stderr}");
    throw Exception("WemToWav: File not found ($wavPath)");
  }
}

Future<void> _wemToWavWeb(String wemPath, String wavPath) async {
  var wemFile = await FS.i.read(wemPath);
  var wav = await ServiceWorkerHelper.i.wemToWav(wemFile);
  if (wav.isOk) {
    await FS.i.write(wavPath, wav.ok);
  } else {
    throw Exception("WemToWav: ${wav.errorMessage}");
  }
}
