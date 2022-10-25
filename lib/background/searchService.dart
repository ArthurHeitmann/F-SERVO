
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import '../fileTypeUtils/tmd/tmdReader.dart';
import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../stateManagement/Property.dart';
import '../utils.dart';
import 'IdLookup.dart';
import 'IdsIndexer.dart';

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

class SearchService {
  final StreamController<SearchResult> controller = StreamController<SearchResult>();
  Isolate? _isolate;
  SendPort? _sendPort;
  final _isDoneCompleter = Completer<void>();
  final BoolProp isSearching;

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
      Isolate.spawn(_SearchServiceWorker().search, options)
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
    Future.delayed(Duration(milliseconds: 500)).then((_) {
      _isolate?.kill(priority: Isolate.immediate);
      if (!_isDoneCompleter.isCompleted)
        _isDoneCompleter.complete();
    });
    return _isDoneCompleter.future;
  }
}

/// In new isolate search recursively for files with given extensions in given path
class _SearchServiceWorker {
  bool _isCanceled = false;
  int _resultsCount = 0;
  static const int _maxResults = 1000;

  void search(SearchOptions options) async {
    var receivePort = ReceivePort();
    receivePort.listen(_onMessage);
    options.sendPort!.send(receivePort.sendPort);
    var t1 = DateTime.now();

    try {
      if (!await Directory(options.searchPath).exists() && !await File(options.searchPath).exists())
        return;
      if (options is SearchOptionsText)
        await _searchTextRec(options.searchPath, options);
      else if (options is SearchOptionsId)
        await _searchIdRec(options.searchPath, options);
    }
    finally {
      options.sendPort!.send("done");
      var t2 = DateTime.now();
      print("Search done in ${t2.difference(t1).inSeconds} s");
    }
  }

  void _onMessage(dynamic message) {
    if (message is String && message == "cancel") {
      _isCanceled = true;
    } else
      print("Unhandled message: $message");
  }

  void _sendResult(SearchResult result, SendPort sendPort) {
    sendPort.send(result);
    _resultsCount++;
    if (_resultsCount >= _maxResults)
      _isCanceled = true;
  }

  Future<void> _searchTextRec(String filePath, SearchOptionsText options, [bool Function(String)? test]) async {
    if (_isCanceled)
      return;
    test ??= _initTestFuncStr(options);
    var file = File(filePath);
    if (await file.exists()) {
      if (options.fileExtensions.isNotEmpty && !options.fileExtensions.contains(path.extension(filePath)))
        return;
      List<String> lines;
      if (!options.isMultiline) {
        lines = await _getFileLines(file, options);
        for (int i = 0; i < lines.length; i++) {
          var line = lines[i];
          if (!test(line))
            continue;
          _sendResult(SearchResultText(filePath, line, i + 1), options.sendPort!);
        }
      }
      else {
        String content = await _getFileContent(file, options);
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
          _sendResult(SearchResultText(filePath, matchStr, lineNum), options.sendPort!);
        }
      }
    }
    else {
      var dirList = await Directory(filePath).list().toList();
      if (options.fileExtensions.isNotEmpty) {
        dirList = dirList
          .where((fse) => fse is! File || options.fileExtensions.contains(path.extension(fse.path)))
          .toList();
      }
      List<Future> futures = [];
      for (var dir in dirList) {
        futures.add(_searchTextRec(dir.path, options, test));
      }
      await Future.wait(futures);
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
  
  Future<String> _getFileContent(File file, SearchOptionsText options) async {
    if (file.path.endsWith(".tmd")) {
      var entries = await readTmdFile(file.path);
      return entries.map((e) => e.toString()).join("\n");
    }
    else if (file.path.endsWith(".tmd")) {
      var entries = await readTmdFile(file.path);
      return entries.map((e) => e.toString()).join("\n");
    }
    try {
      return await file.readAsString();
    }
    catch (e) {
      return "";
    }
  }

  Future<List<String>> _getFileLines(File file, SearchOptionsText options) async {
    if (file.path.endsWith(".tmd")) {
      var entries = await readTmdFile(file.path);
      return entries
        .map((e) => e.toString().split("\n"))
        .expand((e) => e)
        .toList();
    }
    else if (file.path.endsWith(".tmd")) {
      var entries = await readTmdFile(file.path);
      return entries
        .map((e) => e.toString().split("\n"))
        .expand((e) => e)
        .toList();
    }
    try {
      return await file.readAsLines();
    }
    catch (e) {
      return [];
    }
  }

  Future<void> _searchIdRec(String filePath, SearchOptionsId options) async {
    if (_isCanceled)
      return;
    var file = File(filePath);
    if (await file.exists()) {
      if (options.fileExtensions.isNotEmpty && !options.fileExtensions.contains(path.extension(filePath)))
        return;
      if (path.extension(filePath) == ".yax")
        return;
      String xmlText;
      try {
        xmlText = await file.readAsString();
      } catch (e) {
        return;
      }
      if (!xmlText.toLowerCase().contains(options.idHex))
        return;
      var xmlDoc = XmlDocument.parse(xmlText);
      var xmlRoot = xmlDoc.rootElement;
      _searchIdInXml(filePath, xmlRoot, options);
    }
    else {
      var dirList = await Directory(filePath).list().toList();
      if (options.fileExtensions.isNotEmpty) {
        dirList = dirList
          .where((fse) => fse is! File || options.fileExtensions.contains(path.extension(fse.path)))
          .toList();
      }
      List<Future> futures = [];
      for (var dir in dirList) {
        futures.add(_searchIdRec(dir.path, options));
      }
      await Future.wait(futures);
    }
  }

  void _optionallySendIdData(IndexedIdData idData, SearchOptionsId options) {
    if (idData.id != options.id)
      return;
    _sendResult(SearchResultId(idData.xmlPath, idData), options.sendPort!);
  }

  void _searchIdInXml(String filePath, XmlElement root, SearchOptionsId options) {
    var fileId = root.getElement("id")?.text;
    if (fileId != null) {
      var id = int.parse(fileId);
      _optionallySendIdData(IndexedIdData(
        id, "HAP",
        "", "", filePath,
      ), options);
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
      ), options);

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
          ), options);
        }
      }
    }
  }
}
