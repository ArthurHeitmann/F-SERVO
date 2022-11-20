
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/utils.dart';
import '../../utils/assetDirFinder.dart';

Future<bool> _processFile(String filePath) async {
  await assetDirDone;
  if (assetsDir == null) {
    showToast("Assets directory not found");
    return false;
  }
  if (!await hasPython()) {
    showToast("Python not found");
    return false;
  }
  var pyToolPath = join(assetsDir!, "MrubyDecompiler", "__init__.py");
  var result = await Process.run(pythonCmd!, [pyToolPath, filePath]);
  return result.exitCode == 0;
}

Future<bool> binFileToRuby(String filePath) {
  print("Decompiling $filePath");
  messageLog.add("Decompiling ${basename(filePath)}");
  return _processFile(filePath);
}

Future<bool> rubyFileToBin(String filePath) async {
  print("Compiling $filePath");
  messageLog.add("Compiling ${basename(filePath)}");
  var result = await _processFile(filePath);
  if (!result)
    return false;
  // TODO is .bin and not .mrb
  var mrbPath = "$filePath.mrb";
  var binPath = withoutExtension(filePath);
  await File(mrbPath).copy(binPath);
  await File(mrbPath).delete();
  return true;
}
