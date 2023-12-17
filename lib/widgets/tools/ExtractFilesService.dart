
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

import '../../fileTypeUtils/audio/bnkExtractor.dart';
import '../../fileTypeUtils/bxm/bxmReader.dart';
import '../../fileTypeUtils/cpk/cpkExtractor.dart';
import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/pak/pakExtractor.dart';
import '../../fileTypeUtils/ruby/pythonRuby.dart';
import '../../fileTypeUtils/wta/wtaExtractor.dart';
import '../../stateManagement/hasUuid.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';

class ExtractFilesParam {
  List<String>? selectedFiles;
  String? selectedDirectory;
  bool recursive;
  String? cpkExtractDirectory;
  bool extractCpk;
  bool extractDat;
  bool extractWta;
  bool extractBnk;
  bool convertScripts;
  bool convertBxm;
  late SendPort sendPort;
  late ReceivePort receivePort;
  late String? assetsDir;
  late int id;

  ExtractFilesParam(this.selectedFiles, this.selectedDirectory, this.recursive,
      this.cpkExtractDirectory, this.extractCpk, this.extractDat, this.extractWta,
      this.extractBnk, this.convertScripts, this.convertBxm);

  ExtractFilesParam copy() => ExtractFilesParam(
    selectedFiles,
    selectedDirectory,
    recursive,
    cpkExtractDirectory,
    extractCpk,
    extractDat,
    extractWta,
    extractBnk,
    convertScripts,
    convertBxm
  );

}

enum _MessageType {
  done,
  incrementDone,
  incrementRemaining,
  sendPort,
}

class _WorkerWrapper {
  final int id;
  final ReceivePort receivePort;
  SendPort? sendPort;
  Isolate? isolate;

  _WorkerWrapper(this.id,  this.receivePort);
}

class FileExtractorService with HasUuid {
  final List<_WorkerWrapper> _activeWorkers = [];
  final List<ExtractFilesParam> _filesQueue = [];
  int _nextId = 0;
  final int _maxWorkers;
  final ValueNotifier<bool> isRunning = ValueNotifier(true);
  final ValueNotifier<int> processedFiles = ValueNotifier(0);
  final ValueNotifier<int> remainingFiles = ValueNotifier(0);

  FileExtractorService()
    : _maxWorkers = max(1, Platform.numberOfProcessors ~/ 2);

  void extract(ExtractFilesParam param) async {
    if (param.selectedFiles != null && param.selectedDirectory != null)
      throw Exception("Cannot extract files from both files and directory");
    if (param.selectedFiles == null && param.selectedDirectory == null)
      throw Exception("No files or directory selected");
    if (param.selectedFiles != null) {
      remainingFiles.value += param.selectedFiles!.length;
      for (var file in param.selectedFiles!) {
        var workerParam = param.copy();
        workerParam.selectedFiles = [file];
        workerParam.selectedDirectory = null;
        workerParam.id = _nextId++;
        _filesQueue.add(workerParam);
      }
    }
    else if (param.selectedDirectory != null) {
      var allFiles = (await Directory(param.selectedDirectory!)
        .list(recursive: param.recursive)
        .toList())
        .whereType<File>();
      remainingFiles.value += allFiles.length;
      for (var file in allFiles) {
        var workerParam = param.copy();
        workerParam.selectedFiles = [file.path];
        workerParam.selectedDirectory = null;
        workerParam.id = _nextId++;
        _filesQueue.add(workerParam);
      }
    }

    _dequeueAvailable();
  }

  Future<void> stop() async {
    for (var worker in _activeWorkers) {
      worker.sendPort?.send({
        "type": _MessageType.done.index,
        "id": worker.id,
      });
    }
    await Future.delayed(const Duration(milliseconds: 250));
  }

  void dispose() {
    for (var worker in _activeWorkers) {
      worker.isolate?.kill();
      worker.receivePort.close();
    }
    isRunning.dispose();
    processedFiles.dispose();
    remainingFiles.dispose();
  }

  void _dequeueAvailable() async {
    while (_activeWorkers.length < _maxWorkers && _filesQueue.isNotEmpty)
      await _dequeueOne();
    if (_activeWorkers.isEmpty && _filesQueue.isEmpty)
      isRunning.value = false;
  }

  Future<void> _dequeueOne() async {
    var param = _filesQueue.removeAt(0);
    var worker = _WorkerWrapper(param.id, ReceivePort());
    param.sendPort = worker.receivePort.sendPort;
    param.assetsDir = assetsDir;
    worker.receivePort.listen(_handleMessage);
    var isolate = await Isolate.spawn(_FileExtractorWorker.extract, param);
    worker.isolate = isolate;
    _activeWorkers.add(worker);
  }

  void _handleMessage(dynamic message) {
    var type = _MessageType.values[message["type"]];
    var id = message["id"];
    var worker = _activeWorkers.firstWhere((e) => e.id == id);
    switch (type) {
      case _MessageType.done:
        worker.isolate!.kill();
        worker.receivePort.close();
        _activeWorkers.remove(worker);
        _dequeueAvailable();
        break;
      case _MessageType.incrementRemaining:
        var count = message["count"] as int;
        remainingFiles.value += count;
        break;
      case _MessageType.incrementDone:
        var count = message["count"] as int;
        processedFiles.value += count;
        remainingFiles.value -= count;
        break;
      case _MessageType.sendPort:
        worker.sendPort = message["sendPort"];
        break;
      default:
        throw Exception("Unknown message type $type");
    }
  }
}

class _FileExtractorWorker {
  bool _shouldRun = true;
  late ExtractFilesParam _param;

  static void extract(ExtractFilesParam param) async {
    var worker = _FileExtractorWorker();
    worker._param = param;
    param.receivePort = ReceivePort();
    param.receivePort.listen(worker._handleMessage);
    param.sendPort.send({
      "type": _MessageType.sendPort.index,
      "id": param.id,
      "sendPort": param.receivePort.sendPort,
    });
    try {
      await worker._run();
    } finally {
      param.sendPort.send({
        "type": _MessageType.done.index,
        "id": param.id,
      });
    }
  }

  Future<void> _run() async {
    List<String> pendingFiles = _param.selectedFiles!.toList();
    while (_shouldRun && pendingFiles.isNotEmpty) {
      var file = pendingFiles.removeAt(0);
      try {
        var newFiles = await _processFile(file);
        pendingFiles.addAll(newFiles);
        if (newFiles.isNotEmpty) {
          _param.sendPort.send({
            "type": _MessageType.incrementRemaining.index,
            "id": _param.id,
            "count": newFiles.length,
          });
        }
      } catch (e, stackTrace) {
        print("Error processing file $file: $e");
        print(stackTrace);
      }
      _param.sendPort.send({
        "type": _MessageType.incrementDone.index,
        "id": _param.id,
        "count": 1,
      });
    }
  }

  Future<List<String>> _processFile(String file) async {
    var pendingFiles = <String>[];
    if (file.endsWith(".cpk") && _param.extractCpk) {
      pendingFiles.addAll(await extractCpk(file, extractDir: _param.cpkExtractDirectory, logProgress: false));
    }
    else if (datExtensions.any((ext) => file.endsWith(ext)) && _param.extractDat) {
      pendingFiles.addAll(await extractDatFiles(file));
    }
    else if ((file.endsWith(".wta")) && _param.extractWta) {
      var wtpPath = await _findWtp(file);
      if (wtpPath != null)
        await extractWta(file, wtpPath, false);
    }
    else if (file.endsWith(".wtb") && _param.extractWta) {
      await extractWta(file, null, true);
    }
    else if (file.endsWith(".bnk") && _param.extractBnk) {
      await extractBnkWemsFromPath(file);
    }
    else if (bxmExtensions.any((ext) => file.endsWith(ext)) && _param.convertBxm) {
      await convertBxmFileToXml(file, "$file.xml");
    }
    else if (file.endsWith("_scp.bin") && _param.convertScripts) {
      await binFileToRuby(file, isIsolate: true, customAssetsDir: _param.assetsDir);
    }
    else if (file.endsWith(".pak") && _param.convertScripts) {
      await extractPakFiles(file, yaxToXml: true);
    }
    else {
      // print("Unknown file type: $file");
    }
    return pendingFiles;
  }

  void _handleMessage(dynamic message) {
    var type = _MessageType.values[message["type"]];
    switch (type) {
      case _MessageType.done:
        _shouldRun = false;
        break;
      default:
        throw Exception("Unknown message type $type");
    }
  }

  Future<String?> _findWtp(String wtaPath) async {
    var wtpName = "${basenameWithoutExtension(wtaPath)}.wtp";
    var datDir = dirname(wtaPath);
    var wtpPath = join(datDir, wtpName);
    if (await File(wtpPath).exists())
      return wtpPath;
    var dttDir = await findDttDirOfDat(datDir);
    if (dttDir != null)
      wtpPath = join(dttDir, wtpName);
    if (!await File(wtpPath).exists())
      return null;
    return wtpPath;
  }
}
