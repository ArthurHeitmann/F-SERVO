
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

String? assetsDir;
Completer<void> _assetDirSearchCompleter = Completer();
Future<void> assetDirDone = _assetDirSearchCompleter.future;

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
      assetsDir = path;
      _assetDirSearchCompleter.complete();
      print("Found assets dir at $path");
      return true;
    }
    searchPathsQueue.addAll(subDirs);
  }
  print("Couldn't find assets dir");
  return false;
}