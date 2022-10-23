
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import '../../stateManagement/statusInfo.dart';
import '../../utils.dart';

String? _assetsDir;
Completer<void> _assetDirSearchCompleter = Completer();
Future<void> _assetDirSearch = _assetDirSearchCompleter.future;

const _assetsDirName = "assets";
const _assetsDirSubDirs = { "fonts", "MrubyDecompiler" };
Future<bool> findAssetsDir() async {
  var path = Directory.current.path;
  // search cwd breadth first
  List<String> searchPathsQueue = [path];
  while (searchPathsQueue.isNotEmpty) {
    path = searchPathsQueue.removeAt(0);
    var subDirs = await Directory(path)
      .list()
      .where((f) => f is Directory)
      .map((f) => f.path)
      .toList();
    var subDirNames = subDirs.map((p) => basename(p)).toSet();
    if (basename(path) == _assetsDirName && _assetsDirSubDirs.every((subDir) => subDirNames.contains(subDir))) {
      _assetsDir = path;
      _assetDirSearchCompleter.complete();
      print("Found assets dir at $path");
      return true;
    }
    searchPathsQueue.addAll(subDirs);
  }
  print("Couldn't find assets dir");
  return false;
}

Future<bool> _processFile(String filePath) async {
  await _assetDirSearch;
  if (_assetsDir == null) {
    showToast("Assets directory not found");
    return false;
  }
  var pyToolPath = join(_assetsDir!, "MrubyDecompiler", "__init__.py");
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
