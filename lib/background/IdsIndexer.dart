
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../fileTypeUtils/yax/yaxToXml.dart';
import '../../utils.dart';

class IndexedIdData {
  final int id;
  final String datPath;
  final String pakPath;
  final String xmlPath;

  IndexedIdData(this.id, this.datPath, this.pakPath, this.xmlPath);
}

class IndexedEntityIdData extends IndexedIdData {
  final String objId;
  final int actionId;
  final String? name;
  final int? level;

  IndexedEntityIdData(int id, String datPath, String pakPath, String xmlPath, this.objId, this.actionId, this.name, this.level) : super(id, datPath, pakPath, xmlPath);
}

enum InitStatus {
  notInitialized,
  initializing,
  initialized,
}

class IdsIndexer {
  String? _path;
  final Map<int, IndexedIdData> indexedIds = {};

  InitStatus _initStatus = InitStatus.notInitialized;
  final _awaitInitializedCompleter = Completer<void>();

  String? get path => _path;

  Future<void> indexPath(String path) async {
    _path = path;
    _initStatus = InitStatus.notInitialized;
    await _init(path);
  }

  void clear() {
    _path = null;
    indexedIds.clear();
    _initStatus = InitStatus.notInitialized;
  }

  Future<void> awaitInitialized() {
    switch (_initStatus) {
      case InitStatus.notInitialized:
        if (_path == null)
          return Future.value();
        return _init(_path!);
      case InitStatus.initializing:
        return _awaitInitializedCompleter.future;
      case InitStatus.initialized:
        return Future.value();
    }
  }

  Future<void> _init(String path) async {
    if (_initStatus != InitStatus.notInitialized)
      return;
    _initStatus = InitStatus.initializing;

    await indexAllIds(path);

    _initStatus = InitStatus.initialized;
    _awaitInitializedCompleter.complete();
  }

  int foundXmlFiles = 0;
  Future<void> indexAllIds(String dir) async {
    print("Indexing ids in $dir");
    foundXmlFiles = 0;
    int t1 = DateTime.now().millisecondsSinceEpoch;
    await _indexAllIdsInDir(dir);
    int t2 = DateTime.now().millisecondsSinceEpoch;
    print("Found $foundXmlFiles xml files with ${indexedIds.length} IDs in ${t2 - t1}ms");
  }

  Future<void> _indexAllIdsInDir(String dir) async {
    List<Future<void>> futures = [];
    await for (var entry in Directory(dir)
      .list(recursive: true)
      .where((f) => f is File && f.path.endsWith(".dat"))
    ) {
        futures.add(_indexDatContents(entry.path));
    }
    await Future.wait(futures);
  }

  Future<void> _indexDatContents(String datPath) async {
    List<Future<void>> futures = [];
    var fileName = basename(datPath);
    var datFolder = dirname(datPath);
    var datExtractDir = join(datFolder, "nier2blender_extracted", fileName);

    if (await Directory(datExtractDir).exists()) {
      var pakFiles = (await getDatFiles(datExtractDir))
                    .where((f) => f.endsWith(".pak"));
      for (var pakFile in pakFiles) {
        var pakPath = join(datExtractDir, pakFile);
        var pakExtractDir = join(datExtractDir, "pakExtracted", basename(pakFile));
        var pakFileBytes = (await File(pakPath).readAsBytes()).buffer.asByteData();
        // futures.add(_indexPakContents(datPath, pakPath, pakExtractDir, pakFileBytes));
        await _indexPakContents(datPath, pakPath, pakExtractDir, pakFileBytes);
      }
    }
    else {
      await for (var fileData in extractDatFilesAsStream(datPath)) {
        if (!fileData.path.endsWith(".pak"))
          continue;
        var pakExtractDir = join(datExtractDir, "pakExtracted", basename(fileData.path));
        // futures.add(_indexPakContents(datPath, fileData.path, pakExtractDir, fileData.bytes.asByteData()));
        await _indexPakContents(datPath, fileData.path, pakExtractDir, fileData.bytes.asByteData());
      }
    }

    await Future.wait(futures);
  }

  Future<void> _indexPakContents(String datPath, String pakPath, String pakExtractPath, ByteData bytes) async {
    List<Future<void>> futures = [];
    var pakInfoPath = join(pakExtractPath, "pakInfo.json");

    if (await File(pakInfoPath).exists()) {
      var pakInfoJson = jsonDecode(await File(pakInfoPath).readAsString());
      var pakFiles = (pakInfoJson["files"] as List)
                      .map((f) => f["name"])
                      .toList();
      for (var yaxFile in pakFiles) {
        var yaxPath = join(pakExtractPath, yaxFile);
        var yaxBytes = (await File(yaxPath).readAsBytes());
        // futures.add(_indexYaxContents(datPath, pakPath, yaxPath, yaxBytes.buffer.asByteData()));
        await _indexYaxContents(datPath, pakPath, yaxPath, yaxBytes.buffer.asByteData());
      }
    }

    await Future.wait(futures);
  }

  Future<void> _indexYaxContents(String datPath, String pakPath, String yaxPath, ByteData bytes) async {
    var xmlPath = setExtension(yaxPath, ".xml");
    
    if (await File(xmlPath).exists()) {
      var xmlDoc = XmlDocument.parse(await File(xmlPath).readAsString());
      var xmlRoot = xmlDoc.rootElement;
      _indexXmlContents(datPath, pakPath, yaxPath, xmlRoot);
    }
    else {
      var xmlRoot = yaxToXml(ByteDataWrapper(bytes), includeAnnotations: false);
      _indexXmlContents(datPath, pakPath, yaxPath, xmlRoot);
    }
  }

  void _indexXmlContents(String datPath, String pakPath, String xmlPath, XmlElement root) {
    foundXmlFiles++;

    var hapIdL = root.findElements("id");
    if (hapIdL.isNotEmpty) {
      var hapId = int.parse(hapIdL.first.text);
      indexedIds[hapId] = IndexedIdData(hapId, datPath, pakPath, xmlPath);
    }

    for (var action in root.findElements("action")) {
      var actionId = int.parse(action.findElements("id").first.text);
      indexedIds[actionId] = IndexedIdData(actionId, datPath, pakPath, xmlPath);

      for (var normal in action.findAllElements("normal")) {
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

          indexedIds[entityId] = IndexedEntityIdData(entityId, datPath, pakPath, xmlPath, objId, actionId, name, level);
        }
      }
    }
  }
}

final indexingService = IdsIndexer();
