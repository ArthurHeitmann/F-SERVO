
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/statusInfo.dart';

Future<bool> _processFile(String filePath) async {
  var cwd = Directory.current.path;
  var pyToolPath = join(cwd, "lib", "fileTypeUtils", "ruby", "MrubyDecompiler", "__init__.py");
  var result = await Process.run("python", [pyToolPath, filePath]);
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
