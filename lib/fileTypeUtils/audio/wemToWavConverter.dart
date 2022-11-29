
import 'dart:io';

import 'package:path/path.dart';

import '../../utils/assetDirFinder.dart';

String? _tmpWavPath;

Future<String> wemToWav(String wemPath) async {
  _tmpWavPath ??= (await Directory.systemTemp.createTemp("wemToWav")).path;
  var tempWavPath = join(_tmpWavPath!, "${basenameWithoutExtension(wemPath)}.wav");
  var vgmStreamPath = join(assetsDir!, "bins", "vgmStream", "vgmStream.exe");
  var process = await Process.run(vgmStreamPath, ["-o", tempWavPath, wemPath]);
  if (process.exitCode != 0) {
    print("stdout: ${process.stdout}");
    print("stderr: ${process.stderr}");
    throw Exception("WemToWav: Process exited with code ${process.exitCode}");
  }
  if (!await File(tempWavPath).exists()) {
    throw Exception("WemToWav: File not found ($tempWavPath)");
  }
  return tempWavPath;
}
