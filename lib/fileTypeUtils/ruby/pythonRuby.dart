
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/events/statusInfo.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';

Future<bool> _processFile(String filePath, String? assetsDir, bool isIsolate) async {
  void Function(String) errorPrint = isIsolate ? print : showToast;
  if (assetsDir == null) {
    errorPrint("Assets directory not found");
    return false;
  }
  if (!await hasPython()) {
    errorPrint("Python not found");
    return false;
  }
  var pyToolPath = join(assetsDir, "MrubyDecompiler", "__init__.py");
  var result = await Process.run(pythonCmd!, [pyToolPath, filePath]);
  var isSuccessful = result.exitCode == 0 && result.stderr.isEmpty;
  if (!isSuccessful) {
    for (String line in result.stderr.split("\n"))
      messageLog.add(line.replaceAll("\r", "").trim());
    errorPrint("Failed to process ${basename(filePath)}");
    print(result.stdout);
    print(result.stderr);
  }
  return isSuccessful;
}

Future<bool> binFileToRuby(String filePath, { bool isIsolate = false, String? customAssetsDir }) {
  messageLog.add("Decompiling ${basename(filePath)}");
  return _processFile(
    filePath,
    customAssetsDir ?? assetsDir,
    isIsolate
  );
}

Future<bool> rubyFileToBin(String filePath) async {
  messageLog.add("Compiling ${basename(filePath)}");
  var result = await _processFile(filePath, assetsDir, false);
  if (!result)
    return false;
  // TODO is .bin and not .mrb
  var mrbPath = "$filePath.mrb";
  var binPath = withoutExtension(filePath);
  await File(mrbPath).copy(binPath);
  await File(mrbPath).delete();
  return true;
}
