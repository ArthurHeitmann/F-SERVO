
import 'dart:io';

import 'package:path/path.dart';

void main() async {
  var result = await Process.start(
    "flutter", ["build", "web", "--pwa-strategy=none"],
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await result.exitCode != 0) {
    print("Error building web: ${result.stderr}");
    exit(1);
  }

  File? workerFile;
  for (var file in Directory(join("assets", "web_worker", "dist")).listSync()) {
    if (file is! File)
      continue;
    var fileName = basename(file.path);
    if (fileName == "index.html") {
      continue;
    }
    if (fileName == "worker.js") {
      workerFile = file;
      continue;
    }
    var newPath = join("build", "web", fileName);
    file.copySync(newPath);
    print("Copied $fileName to $newPath");
  }

  var flutterWorker = File(join("build", "web", "flutter_service_worker.js"));
  var flutterWorkerJs = flutterWorker.readAsStringSync();
  var workerJs = workerFile?.readAsStringSync() ?? "";
  const marker = "\n/* custom worker */";
  var markerIndex = flutterWorkerJs.indexOf(marker);
  if (markerIndex != -1) {
    flutterWorkerJs = flutterWorkerJs.substring(0, markerIndex);
  }
  var newWorkerJs = "$flutterWorkerJs$marker\n$workerJs";
  flutterWorker.writeAsStringSync(newWorkerJs);
  print("Merged $flutterWorker and $workerFile to $flutterWorker");
}
