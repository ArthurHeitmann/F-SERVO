
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:http/http.dart' as http;

import '../stateManagement/events/statusInfo.dart';
import '../stateManagement/hierarchy/FileHierarchy.dart';
import '../stateManagement/hierarchy/HierarchyEntryTypes.dart';
import '../stateManagement/openFiles/openFilesManager.dart';
import '../utils/assetDirFinder.dart';
import '../utils/utils.dart';
import 'retrieveReleases.dart';
import 'updateRestartData.dart';

Future<void> installRelease(GitHubReleaseInfo release, StreamController<String> updateStepStream, StreamController<double> updateProgressStream) async {
  updateStepStream.add("Preparing update...");
  updateProgressStream.add(0);
  var downloadName = basename(release.downloadUrl);
  var appDir = dirname(Platform.resolvedExecutable);
  var updateDir = join(appDir, "_update");
  var updateDirCache = join(updateDir, "cache");
  var updateDirTemp = join(updateDir, "temp");
  String errorMessage = "";
  IOSink? updateFile_;
  try {
    if (await Directory(updateDirTemp).exists()) {
      errorMessage = "Failed to delete temp update directory";
      await Directory(updateDirTemp).delete(recursive: true);
    }
    errorMessage = "Failed to create update directory";
    await Directory(updateDir).create(recursive: true);
    await Directory(updateDirCache).create();
    await Directory(updateDirTemp).create();

    errorMessage = "7z.exe or dll not found";
    var exe7z = await _get7zExe(updateDirCache);
    errorMessage = "updater.exe not found";
    var exeUpdater = await _getUpdaterExe(updateDirTemp);

    var updateFilePath = join(updateDirCache, downloadName);

    var needsDownload = !await File(updateFilePath).exists() || await File(updateFilePath).length() != release.downloadSize;
    if (needsDownload) {
      var updateFile = File(updateFilePath).openWrite();
      updateFile_ = updateFile;
      errorMessage = "Failed to download $downloadName";
      updateStepStream.add("Downloading $downloadName...");
      var response = await http.Client().send(http.Request("GET", Uri.parse(release.downloadUrl)));
      var totalBytes = response.contentLength ?? release.downloadSize;
      var receivedBytes = 0;
      var downloadCompleter = Completer<void>();
      response.stream.listen(
        (chunk) {
          updateFile.add(chunk);
          receivedBytes += chunk.length;
          updateProgressStream.add(receivedBytes / totalBytes);
        },
        onDone: () async {
          downloadCompleter.complete();
        },
        onError: (e) {
          downloadCompleter.completeError(e);
        },
      );
      await downloadCompleter.future;
      await updateFile_.close();
      updateFile_ = null;
    }

    errorMessage = "Failed to extract $downloadName";
    updateStepStream.add("Extracting $downloadName...");
    var extractDir = join(updateDirTemp, basenameWithoutExtension(release.downloadUrl));
    await Directory(extractDir).create();
    var result = await Process.run(exe7z, ["x", "-y", "-o$extractDir", updateFilePath]);
    if (result.exitCode != 0) {
      throw Exception("7z failed with exit code ${result.exitCode} and message: ${result.stderr}");
    }
    await Future.delayed(const Duration(milliseconds: 250));

    var backupDir = join(updateDirTemp, "backup");
    await Directory(backupDir).create();

    var openFiles = areasManager.areas
      .map((e) => e.files)
      .expand((e) => e)
      .map((e) => e.path)
      .toList();
    var openHierarchies = openHierarchyManager.children
      .whereType<FileHierarchyEntry>()
      .map((e) => e.path).toList();
    var restartData = UpdateRestartData(openFiles, openHierarchies);
    var restartDataJson = restartData.toJson();
    var restartDataJsonString = base64Encode(utf8.encode(jsonEncode(restartDataJson)));

    await Process.start(
      exeUpdater,
      ["--app-dir", appDir, "--extracted-dir", extractDir, "--backup-dir", backupDir, "--exe-path", Platform.resolvedExecutable, "--restart-data", restartDataJsonString],
      mode: ProcessStartMode.detached,
    );
  } catch (e, st) {
    messageLog.add("$errorMessage: $e\n$st");
    showToast(errorMessage);
    throw Exception(errorMessage);
  } finally {
    await updateFile_?.close();
  }
}

Future<String> _get7zExe(String cacheDir) async {
  var src7zExe = join(assetsDir!, "bins", "7z.exe");
  var src7zDll = join(assetsDir!, "bins", "7z.dll");
  var dst7zExe = join(cacheDir, "7z.exe");
  var dst7zDll = join(cacheDir, "7z.dll");
  await File(src7zExe).copy(dst7zExe);
  await File(src7zDll).copy(dst7zDll);
  return dst7zExe;
}

Future<String> _getUpdaterExe(String tempDir) async {
  var srcUpdaterExe = join(assetsDir!, "bins", "updater.exe");
  var dstUpdaterExe = join(tempDir, "updater.exe");
  await File(srcUpdaterExe).copy(dstUpdaterExe);
  return dstUpdaterExe;
}
