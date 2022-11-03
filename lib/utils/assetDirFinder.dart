
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

bool _hasMrubyAssetsComplete = false;
bool _hasMrubyAssets = false;
Future<bool> hasMrubyAssets() async {
  if (_hasMrubyAssetsComplete)
    return _hasMrubyAssets;
  await assetDirDone;
  var mrubyDir = join(assetsDir!, "MrubyDecompiler");
  var mrubyFiles = await Directory(mrubyDir)
    .list()
    .map((f) => basename(f.path))
    .toList();
  _hasMrubyAssets = mrubyFiles.contains("__init__.py") && mrubyFiles.contains("bins");
  _hasMrubyAssetsComplete = true;
  return _hasMrubyAssets;
}

bool _hasMagickBinsComplete = false;
bool _hasMagickBins = false;
String? magickBinPath;
Future<bool> hasMagickBins() async {
  if (_hasMagickBinsComplete)
    return _hasMagickBins;
  await assetDirDone;
  var magickDir = join(assetsDir!, "bins");
  var magickFiles = await Directory(magickDir)
    .list()
    .map((f) => basename(f.path))
    .toList();
  _hasMagickBinsComplete = true;
  _hasMagickBins = magickFiles.contains("magick.exe") && magickFiles.contains("magickLin");
  if (_hasMagickBins) {
    if (Platform.isWindows)
      magickBinPath = join(magickDir, "magick.exe");
    else
      magickBinPath = join(magickDir, "magickLin");
  }
  return _hasMagickBins;
}

bool _hasMcdFontsComplete = false;
bool _hasMcdFonts = false;
const fontIds = [ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "19", "20", "35", "36", "37" ];
Future<bool> hasMcdFonts() async {
  if (_hasMcdFontsComplete)
    return _hasMcdFonts;
  await assetDirDone;
  var fontsDir = join(assetsDir!, "mcdFonts");
  var fontDirs = await Directory(fontsDir)
    .list()
    .where((f) => f is Directory)
    .map((f) => basename(f.path))
    .where((f) => fontIds.contains(f))
    .toList();
  fontDirs.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  if (!listEquals(fontDirs, fontIds))
    return false;
  var allFontsComplete = await Future.wait(fontDirs.map((f) async {
    var fontDir = join(fontsDir, f);
    var fontFiles = await Directory(fontDir)
      .list()
      .map((f) => basename(f.path))
      .toList();
    return fontFiles.contains("_atlas.png") && fontFiles.contains("_atlas.json");
  }));
  _hasMcdFonts = allFontsComplete.every((f) => f);
  _hasMcdFontsComplete = true;
  return _hasMcdFonts;
}

String? pythonCmd;
bool _hasPythonComplete = false;
bool _hasPython = false;
Future<bool> checkPythonVersion(String cmd) async {
  var result = await Process.run(cmd, ["--version"]);
  if (result.exitCode != 0)
    return false;
  var versionStr = result.stdout.toString();
  var versionMatches = RegExp(r"Python (\d+)\.(\d+)\.(\d+)").allMatches(versionStr).first;
  if (versionMatches.groupCount < 3)
    return false;
  var major = int.parse(versionMatches.group(1)!);
  var minor = int.parse(versionMatches.group(2)!);

  if (major < 3)
    return false;
  if (major == 3 && minor < 7)
    return false;
  
  return true;
}
Future<bool> hasPython() async {
  if (_hasPythonComplete)
    return _hasPython;
  
  if (await checkPythonVersion("python3")) {
    pythonCmd = "python3";
    _hasPython = true;
    _hasPythonComplete = true;
    return true;
  }
  if (await checkPythonVersion("python")) {
    pythonCmd = "python";
    _hasPython = true;
    _hasPythonComplete = true;
    return true;
  }
  _hasPythonComplete = true;
  return false;
}
