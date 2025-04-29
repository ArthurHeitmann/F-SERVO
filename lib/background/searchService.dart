
import 'dart:async';
import 'dart:io' show File;
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import '../fileTypeUtils/effects/estEntryTypes.dart';
import '../fileTypeUtils/effects/estIO.dart';
import '../fileTypeUtils/mcd/mcdIO.dart';
import '../fileTypeUtils/tmd/tmdReader.dart';
import '../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../utils/utils.dart';
import 'IdLookup.dart';
import 'IdsIndexer.dart';
import '../fileSystem/FileSystem.dart';

class SearchResult {
  String filePath;

  SearchResult(this.filePath);
}

class SearchResultText extends SearchResult {
  final String line;
  final int lineNum;

  SearchResultText(super.filePath, this.line, this.lineNum);
}

class SearchResultId extends SearchResult {
  final IndexedIdData idData;

  SearchResultId(super.filePath, this.idData);
}

class SearchResultEst extends SearchResult {
  final List<int> records;

  SearchResultEst(super.filePath, this.records);
}

class SearchOptions {
  final String searchPath;
  final List<String> fileExtensions;
  SendPort? sendPort;

  SearchOptions(this.searchPath, this.fileExtensions);
}

class SearchOptionsText extends SearchOptions {
  final String query;
  final bool isRegex;
  final bool isCaseSensitive;
  final bool isMultiline;

  SearchOptionsText(super.searchPath, super.fileExtensions, this.query, this.isRegex, this.isCaseSensitive, this.isMultiline);
}

class SearchOptionsId extends SearchOptions {
  final int id;
  final String idHex;
  final bool useIndexedData;

  SearchOptionsId(super.searchPath, super.fileExtensions, this.id, this.useIndexedData)
    : idHex = id.toRadixString(16);
}

class SearchOptionsEst extends SearchOptions {
  final int? textureFileId;
  final int? textureIndex;
  final int? meshId;
  final int? importedEstId;

  SearchOptionsEst(super.searchPath, super.fileExtensions, this.textureFileId, this.textureIndex, this.meshId, this.importedEstId);
}

class SearchService {
  final StreamController<SearchResult> controller = StreamController<SearchResult>();
  Isolate? _isolate;
  SendPort? _sendPort;
  final _isDoneCompleter = Completer<void>();
  final ValueNotifier<bool> isSearching;

  SearchService({ required this.isSearching });

  Stream<SearchResult> search(SearchOptions options) {
    isSearching.value = true;
    if (options is SearchOptionsId && options.useIndexedData) {
      _searchId(options);
    }
    else {
      ReceivePort receivePort = ReceivePort();
      receivePort.listen(onMessage);
      options.sendPort = receivePort.sendPort;
      Isolate.spawn(_SearchServiceWorker.search, options)
        .then((isolate) {
          _isolate = isolate;
          isolate.addOnExitListener(receivePort.sendPort, response: "done");
        });
    }
    
    return controller.stream;
  }

  Future<void> _searchId(SearchOptionsId options) async {
    var ids = await idLookup.lookupId(options.id);
    for (var idData in ids)
      controller.add(SearchResultId(idData.xmlPath, idData));
    onMessage("done");
  }
  
  void onMessage(dynamic message) {
    if (message is SendPort)
      _sendPort = message;
    else if (message is SearchResult)
      controller.add(message);
    else if (message is String && message == "done") {
      if (!_isDoneCompleter.isCompleted) {
        isSearching.value = false;
        _isDoneCompleter.complete();
      }
      if (controller.isClosed)
        return;
      controller.close();
      _isolate?.kill(priority: Isolate.beforeNextEvent);
    } else
      print("Unhandled message: $message");
  }

  Future<void> cancel() {
    _sendPort?.send("cancel");
    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      _isolate?.kill(priority: Isolate.immediate);
      if (!_isDoneCompleter.isCompleted)
        _isDoneCompleter.complete();
    });
    return _isDoneCompleter.future;
  }
}

/// In new isolate search recursively for files with given extensions in given path
abstract class _SearchServiceWorker<T extends SearchOptions> {
  final T options;
  bool _isCanceled = false;
  int _resultsCount = 0;
  static const int _maxResults = 1000;

  _SearchServiceWorker(this.options);

  static void search(SearchOptions options) {
    if (options is SearchOptionsText)
      _SearchTextServiceWorker(options)._startSearch();
    else if (options is SearchOptionsId)
      _SearchIdServiceWorker(options)._startSearch();
    else if (options is SearchOptionsEst)
      _SearchEstServiceWorker(options)._startSearch();
    else
      throw Exception("Unknown search options type");
  }

  void _startSearch() async {
    var receivePort = ReceivePort();
    receivePort.listen(_onMessage);
    options.sendPort!.send(receivePort.sendPort);
    var t1 = DateTime.now();

    try {
      if (!await FS.i.existsDirectory(options.searchPath) && !await FS.i.existsFile(options.searchPath))
        return;
      await _search(options.searchPath);
    }
    finally {
      options.sendPort!.send("done");
      var t2 = DateTime.now();
      print("Search done in ${t2.difference(t1).inSeconds} s");
    }
  }

  Future<void> _search(String searchPath);

  void _onMessage(dynamic message) {
    if (message is String && message == "cancel") {
      _isCanceled = true;
    } else
      print("Unhandled message: $message");
  }

  void _sendResult(SearchResult result) {
    options.sendPort!.send(result);
    _resultsCount++;
    if (_resultsCount >= _maxResults)
      _isCanceled = true;
  }
}

class _SearchTextServiceWorker extends _SearchServiceWorker<SearchOptionsText> {
  _SearchTextServiceWorker(super.options);

  @override
  Future<void> _search(String filePath, [bool Function(String)? test]) async {
    if (_isCanceled)
      return;
    test ??= _initTestFuncStr(options);
    if (await FS.i.existsFile(filePath)) {
      if (options.fileExtensions.isNotEmpty && !options.fileExtensions.contains(path.extension(filePath)))
        return;
      List<String> lines;
      if (!options.isMultiline) {
        lines = await _getFileLines(filePath, options);
        for (int i = 0; i < lines.length; i++) {
          var line = lines[i];
          if (!test(line))
            continue;
          _sendResult(SearchResultText(filePath, line, i + 1));
        }
      }
      else {
        String content = await _getFileContent(filePath, options);
        if (!test(content))
          return;
        var matchPattern = RegExp(
          options.isRegex ? options.query : RegExp.escape(options.query),
          caseSensitive: options.isCaseSensitive
        );
        // convert matches to full lines
        var matches = matchPattern.allMatches(content);
        for (var match in matches) {
          var lineEndI = content.indexOf("\n");
          var line = content.substring(0, lineEndI);
          int lineNum = 1;
          int lineStart = 0;
          int lineEnd = lineStart + line.length;
          while (!between(match.start, lineStart, lineStart + line.length) && lineEndI != -1) {
            lineStart += line.length + 1;
            lineEndI = content.indexOf("\n", lineStart);
            if (lineEndI == -1)
              line = content.substring(lineStart);
            else
              line = content.substring(lineStart, lineEndI);
            lineEnd = lineStart + line.length;
            lineNum++;
          }
          String matchStr = line;
          while (match.end > lineEnd) {
            lineStart += line.length + 1;
            lineEndI = content.indexOf("\n", lineStart);
            if (lineEndI == -1)
              line = content.substring(lineStart);
            else
              line = content.substring(lineStart, lineEndI);
            lineEnd = lineStart + line.length;
            matchStr += "\n$line";
          }
          _sendResult(SearchResultText(filePath, matchStr, lineNum));
        }
      }
    }
    else {
      var dirList = await FS.i.list(filePath).toList();
      if (options.fileExtensions.isNotEmpty) {
        dirList = dirList
          .where((fse) => fse is! File || options.fileExtensions.contains(path.extension(fse.path)))
          .toList();
      }
      await futuresWaitBatched(dirList.map((dir) => _search(dir.path, test)), 20);
    }
  }

  bool Function(String) _initTestFuncStr(SearchOptionsText options) {
    if (options.isRegex) {
      var regex = RegExp(options.query, caseSensitive: options.isCaseSensitive);
      return (line) => regex.hasMatch(line);
    }
    else if (options.isCaseSensitive) {
      return (line) => line.contains(options.query);
    }
    else {
      var query = options.query.toLowerCase();
      return (line) => line.toLowerCase().contains(query);
    }
  }

  Future<String> _getFileContent(String file, SearchOptionsText options) async {
    if (file.endsWith(".tmd")) {
      var entries = await readTmdFile(file);
      return entries.map((e) => e.toString()).join("\n");
    }
    else if (file.endsWith(".tmd")) {
      var entries = await readTmdFile(file);
      return entries.map((e) => e.toString()).join("\n");
    }
    else if (file.endsWith(".mcd")) {
      var mcd = await McdFile.fromFile(file);
      return mcd.encodeAsString(mcd.makeSymbolsMap());
    }
    try {
      return await FS.i.readAsString(file);
    }
    catch (e) {
      return "";
    }
  }

  Future<List<String>> _getFileLines(String file, SearchOptionsText options) async {
    if (file.endsWith(".tmd")) {
      var entries = await readTmdFile(file);
      return entries
        .map((e) => e.toString().split("\n"))
        .expand((e) => e)
        .toList();
    }
    else if (file.endsWith(".tmd")) {
      var entries = await readTmdFile(file);
      return entries
        .map((e) => e.toString().split("\n"))
        .expand((e) => e)
        .toList();
    }
    else if (file.endsWith(".mcd")) {
      var mcd = await McdFile.fromFile(file);
      var symbols = mcd.makeSymbolsMap();
      return mcd.events
        .map((e) => e.encodeAsString(symbols).split("\n"))
        .expand((e) => e)
        .toList();
    }
    try {
      return await FS.i.readAsLines(file);
    }
    catch (e) {
      return [];
    }
  }
}

class _SearchIdServiceWorker extends _SearchServiceWorker<SearchOptionsId> {
  _SearchIdServiceWorker(super.options);

  @override
  Future<void> _search(String filePath) async {
    if (_isCanceled)
      return;
    if (await FS.i.existsFile(filePath)) {
      if (options.fileExtensions.isNotEmpty && !options.fileExtensions.contains(path.extension(filePath)))
        return;
      if (path.extension(filePath) == ".yax")
        return;
      String xmlText;
      try {
        xmlText = await FS.i.readAsString(filePath);
      } catch (e) {
        return;
      }
      if (!xmlText.toLowerCase().contains(options.idHex))
        return;
      var xmlDoc = XmlDocument.parse(xmlText);
      var xmlRoot = xmlDoc.rootElement;
      _searchIdInXml(filePath, xmlRoot);
    }
    else {
      var dirList = await FS.i.list(filePath).toList();
      if (options.fileExtensions.isNotEmpty) {
        dirList = dirList
          .where((fse) => fse is! File || options.fileExtensions.contains(path.extension(fse.path)))
          .toList();
        }
      await futuresWaitBatched(dirList.map((dir) => _search(dir.path)), 20);
    }
  }

  void _optionallySendIdData(IndexedIdData idData) {
    if (idData.id != options.id)
      return;
    _sendResult(SearchResultId(idData.xmlPath, idData));
  }

  void _searchIdInXml(String filePath, XmlElement root) {
    var fileId = root.getElement("id")?.text;
    if (fileId != null) {
      var id = int.parse(fileId);
      _optionallySendIdData(IndexedIdData(
        id, "HAP",
        "", "", filePath,
      ));
    }

    for (var action in root.findElements("action")) {
      var actionCode = int.parse(action.findElements("code").first.text);
      var actionId = int.parse(action.findElements("id").first.text);
      var actionName = action.findElements("name").first.text;
      actionName = tryToTranslate(actionName);
      _optionallySendIdData(IndexedActionIdData(
        actionId,
        "", "", filePath,
        hashToStringMap[actionCode] ?? actionCode.toString(),
        actionName
      ));

      for (var normal in action.findAllElements("normal")) {  // entities
        var normalLayouts = normal.findElements("layouts").first;
        for (var value in normalLayouts.findElements("value")) {
          var entityId = int.parse(value.childElements.first.text);
          var objId = value.findElements("objId").first.text;
          String? name;
          int? level;
          var aliasL = value.findElements("alias");
          if (aliasL.isNotEmpty)
            name = aliasL.first.text;
          var paramsL = value.findElements("param");
          if (paramsL.isNotEmpty) {
            for (var param in paramsL.first.findElements("value")) {
              var paramName = param.childElements.first.text;
              var paramBody = param.childElements.elementAt(2).text;
              if (paramName == "NameTag")
                name = paramBody;
              else if (paramName == "Lv")
                level = int.parse(paramBody);
            }
          }

          _optionallySendIdData(IndexedEntityIdData(
            entityId,
            "", "", filePath,
            objId, actionId,
            name, level
          ));
        }
      }
    }
  }
}
class _SearchEstServiceWorker extends _SearchServiceWorker<SearchOptionsEst> {
  final bool _searchForTexEntries;
  final bool _searchForFwkEntries;

  _SearchEstServiceWorker(super.options) :
    _searchForTexEntries = options.textureFileId != null || options.textureIndex != null || options.meshId != null,
    _searchForFwkEntries = options.importedEstId != null;

  @override
  Future<void> _search(String searchPath) async {
    if (_isCanceled)
      return;
    await for (var file in FS.i.listFiles(searchPath, recursive: true)) {
      if (_isCanceled)
        return;
      if (!options.fileExtensions.any((ext) => file.endsWith(ext)))
        continue;
      var est = EstFile.read(await ByteDataWrapper.fromFile(file));
      List<int> matchingRecords = [];
      for (int i = 0; i < est.records.length; i++) {
        var record = est.records[i];
        if (!_matchesRecord(record))
          continue;
        matchingRecords.add(i);
      }
      if (matchingRecords.isNotEmpty)
        _sendResult(SearchResultEst(file, matchingRecords));
    }
  }

  bool _matchesRecord(List<EstTypeEntry> record) {
    if (_searchForTexEntries) {
      var entry = record.whereType<EstTypeTexEntry>().firstOrNull;
      if (entry == null)
        return false;
      if (options.textureFileId != null && entry.texture_file_id != options.textureFileId)
        return false;
      if (options.textureIndex != null && entry.texture_file_texture_index != options.textureIndex)
        return false;
      if (options.meshId != null && entry.mesh_id != options.meshId)
        return false;
    }
    if (_searchForFwkEntries) {
      var entry = record.whereType<EstTypeFwkEntry>().firstOrNull;
      if (entry == null)
        return false;
      if (options.importedEstId != null && entry.imported_effect_id != options.importedEstId)
        return false;
    }
    return true;
  }
}
