
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

void main(List<String> args) async {
  var parser = ArgParser();
  parser.addOption("app-dir", mandatory: true);
  parser.addOption("extracted-dir", mandatory: true);
  parser.addOption("backup-dir", mandatory: true);
  parser.addOption("exe-path", mandatory: true);
  parser.addOption("restart-data", mandatory: true);
  var results = parser.parse(args);
  var appDir = results.option("app-dir")!;
  var extractedDir = results.option("extracted-dir")!;
  var backupDir = results.option("backup-dir")!;
  var exePath = results.option("exe-path")!;
  var restartData = results.option("restart-data")!;

  const deletableExtensions = [".dll", ".exe"];
  const dataFolderName = "data";
  List<FileSystemEntity> oldFilesToMove = Directory(appDir).listSync()
    .where((e) => e is File && deletableExtensions.contains(extension(e.path)))
    .toList();
  oldFilesToMove.add(Directory(join(appDir, dataFolderName)));

  var newFiles = Directory(extractedDir).listSync();

  print("Killing F-SERVO.exe...");
  Process.runSync("taskkill", ["/F", "/IM", "F-SERVO.exe"]);

  List<FileSystemEntity> movedOldFiles = [];
  List<FileSystemEntity> movedNewFiles = [];
  try {
    print("Moving files to backup directory...");
    for (var file in oldFilesToMove) {
      var newPath = join(backupDir, basename(file.path));
      print("Moving ${file.path} to $newPath");
      await _tryRename(file, newPath);
      movedOldFiles.add(file);
    }
    print("Moving extracted files to app directory...");
    for (var file in newFiles) {
      var newPath = join(appDir, basename(file.path));
      print("Moving ${file.path} to $newPath");
      await _tryRename(file, newPath);
      movedNewFiles.add(file);
    }
  } catch (e) {
    try {
      print("Error moving files, recovering...");
      print("Deleting new files...");
      for (var file in movedNewFiles) {
        print("Deleting ${file.path}");
        await _tryDelete(file);
      }
      print("Moving old files back...");
      for (var file in movedOldFiles) {
        var newPath = join(appDir, basename(file.path));
        print("Moving ${file.path} back to $newPath");
        await _tryRename(file, newPath);
      }
      print("Recovery complete");
    } catch (e, st) {
      print("Error moving files back: $e\n$st");
    }
    print("Update failed. Press enter to exit.");
    stdin.readLineSync();
    rethrow;
  }

  print("Restarting F-SERVO.exe...");
  var result = await Process.start(exePath, ["--update-data", restartData], mode: ProcessStartMode.detached);
  await result.exitCode;

  print("Update complete");
}

const _maxAttempts = 5;
Future<void> _tryRename(FileSystemEntity file, String path, [int attempt = 1]) async {
  try {
    await file.rename(path);
  } catch (e) {
    if (attempt < _maxAttempts) {
      await Future.delayed(Duration(milliseconds: attempt * 100));
      await _tryRename(file, path, attempt + 1);
    } else {
      rethrow;
    }
  }
}

Future<void> _tryDelete(FileSystemEntity file, [int attempt = 1]) async {
  try {
    if (file is Directory) {
      await file.delete(recursive: true);
    } else {
      await file.delete();
    }
  } catch (e) {
    if (attempt < _maxAttempts) {
      await Future.delayed(Duration(milliseconds: attempt * 100));
      await _tryDelete(file, attempt + 1);
    } else {
      rethrow;
    }
  }
}
