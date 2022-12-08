
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../fileTypeUtils/yax/yaxToXml.dart';
import '../utils/utils.dart';
import '../fileTypeUtils/pak/pakExtractor.dart';
import '../fileTypeUtils/yax/hashToStringMap.dart';

class IndexedIdData {
  final int id;
  final String type;
  final String datPath;
  final String pakPath;
  final String xmlPath;

  IndexedIdData(this.id, this.type, this.datPath, this.pakPath, this.xmlPath);

  @override
  String toString() {
    return "IndexedIdData(\n"
      "  id: $id,\n"
      "  type: $type,\n"
      "  datPath: $datPath,\n"
      "  pakPath: $pakPath,\n"
      "  xmlPath: $xmlPath,\n"
      ")";
  }

  @override
  bool operator==(Object other) {
    if (other is! IndexedIdData)
      return false;
    return id == other.id &&
      type == other.type &&
      datPath == other.datPath &&
      pakPath == other.pakPath &&
      xmlPath == other.xmlPath;
  }

  @override
  int get hashCode => Object.hash(id, type, datPath, pakPath, xmlPath);
}

class IndexedActionIdData extends IndexedIdData {
  final String actionName;

  IndexedActionIdData(int id, String datPath, String pakPath, String xmlPath, String actionType, this.actionName)
    : super(id, "Action # $actionType", datPath, pakPath, xmlPath);

  @override
  String toString() {
    return "IndexedActionIdData(\n"
      "  id: $id,\n"
      "  type: $type,\n"
      "  datPath: $datPath,\n"
      "  pakPath: $pakPath,\n"
      "  xmlPath: $xmlPath,\n"
      "  actionName: $actionName,\n"
      ")";
  }

  @override
  bool operator==(Object other) {
    if (other is! IndexedActionIdData)
      return false;
    return super==(other) &&
      actionName == other.actionName;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, actionName);
}

class IndexedEntityIdData extends IndexedIdData {
  final String objId;
  final int actionId;
  final String? name;
  final int? level;

  IndexedEntityIdData(int id, String datPath, String pakPath, String xmlPath, this.objId, this.actionId, this.name, this.level)
    : super(id, "Entity", datPath, pakPath, xmlPath);

  @override
  String toString() {
    return "IndexedEntityIdData(\n"
      "  id: $id,\n"
      "  type: $type,\n"
      "  datPath: $datPath,\n"
      "  pakPath: $pakPath,\n"
      "  xmlPath: $xmlPath,\n"
      "  objId: $objId,\n"
      "  actionId: $actionId,\n"
      "  name: $name,\n"
      "  level: $level,\n"
      ")";
  }

  @override
  bool operator==(Object other) {
    if (other is! IndexedEntityIdData)
      return false;
    return super==(other) &&
      objId == other.objId &&
      actionId == other.actionId &&
      name == other.name &&
      level == other.level;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, objId, actionId, name, level);
}

class IndexedCharNameData {
  final String key;
  final Map<String, String> nameTranslations;

  IndexedCharNameData(this.key, this.nameTranslations);

  @override
  String toString() {
    return "IndexedCharNameData(\n"
      "  key: $key,\n"
      "  nameTranslations: $nameTranslations,\n"
      ")";
  }

  @override
  bool operator==(Object other) {
    if (other is! IndexedCharNameData)
      return false;
    return key == other.key &&
      nameTranslations == other.nameTranslations;
  }

  @override
  int get hashCode => Object.hash(key, nameTranslations);
}

class IndexedSceneStateData {
  final String key;
  final String commentJap;
  final String commentEng;

  IndexedSceneStateData(this.key, this.commentJap, this.commentEng);

  @override
  String toString() {
    return "IndexedSceneStateData(\n"
      "  key: $key,\n"
      "  commentJap: $commentJap,\n"
      "  commentEng: $commentEng,\n"
      ")";
  }

  @override
  bool operator==(Object other) {
    if (other is! IndexedSceneStateData)
      return false;
    return key == other.key &&
      commentJap == other.commentJap &&
      commentEng == other.commentEng;
  }

  @override
  int get hashCode => Object.hash(key, commentJap, commentEng);
}

enum InitStatus {
  notInitialized,
  initializing,
  initialized,
}

class IdsIndexer {
  String? _path;
  bool _stop = false;
  final Map<int, List<IndexedIdData>> indexedIds = {};
  final Map<String, IndexedCharNameData> indexedCharNames = {};
  final Map<String, IndexedSceneStateData> indexedSceneStates = {};
  void Function(bool)? onLoadingStateChange;

  InitStatus _initStatus = InitStatus.notInitialized;
  Completer<void> _awaitInitializedCompleter = Completer<void>();

  String? get path => _path;

  Future<void> indexPath(String path) async {
    onLoadingStateChange?.call(true);
    _path = path;
    _initStatus = InitStatus.notInitialized;
    await _init(path);
    onLoadingStateChange?.call(false);
  }

  void indexXml(XmlElement xml, String path) {
    onLoadingStateChange?.call(true);
    _path = path;
    _initStatus = InitStatus.notInitialized;
    _initXml(xml, path);
    onLoadingStateChange?.call(false);
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

  void stop() {
    _stop = true;
  }

  Future<void> _init(String path) async {
    if (_initStatus != InitStatus.notInitialized)
      return;
    _initStatus = InitStatus.initializing;
    _stop = false;
    _awaitInitializedCompleter = Completer<void>();

    await _indexAllIds(path);

    _initStatus = InitStatus.initialized;
    _awaitInitializedCompleter.complete();
  }

  void _initXml(XmlElement xml, String xmlPath) {
    if (_initStatus != InitStatus.notInitialized)
      return;
    print("Indexing $xmlPath");
    int t1 = DateTime.now().millisecondsSinceEpoch;

    _initStatus = InitStatus.initializing;
    _stop = false;
    _awaitInitializedCompleter = Completer<void>();

    String pakExtractDir = dirname(xmlPath);
    String pakName = basename(pakExtractDir);
    String datExtractDir = dirname(dirname(pakExtractDir));
    String pakPath = join(datExtractDir, pakName);
    String datName = basename(datExtractDir);
    String datPath = join(dirname(dirname(datExtractDir)), datName);

    _indexXmlContents(datPath, pakPath, xmlPath, xml);

    _initStatus = InitStatus.initialized;
    _awaitInitializedCompleter.complete();

    int t2 = DateTime.now().millisecondsSinceEpoch;
    print("Found ${indexedIds.length} IDs in ${t2 - t1}ms");
  }

  int foundXmlFiles = 0;
  Future<void> _indexAllIds(String indexPath) async {
    if (_stop)
      return;
    print("Indexing ids in $indexPath");
    foundXmlFiles = 0;
    int t1 = DateTime.now().millisecondsSinceEpoch;

    if (await Directory(indexPath).exists()) {
      if (indexPath.endsWith(".pak")) {
        String datExtractDir = dirname(dirname(indexPath));
        String datName = basename(datExtractDir);
        String datPath = join(dirname(dirname(datExtractDir)), datName);
        String pakFile = join(datExtractDir, basename(indexPath));
        String pakInfoPath = join(indexPath, "pakInfo.json");
        if (await File(pakInfoPath).exists())
          await _indexPakInfo(datPath, pakFile, indexPath, pakInfoPath);
      }
      else if (indexPath.endsWith(".dat")) {
        String datName = basename(indexPath);
        String datPath = join(dirname(dirname(indexPath)), datName);
        await _indexDatExtractDir(datPath, indexPath);
      }
      else {
        await _indexAllIdsInDir(indexPath);
      }
    }
    else if (indexPath.endsWith(".dat")) {
      _indexDatContents(indexPath);
    }
    else if (indexPath.endsWith(".pak")) {
      String datExtractDir = dirname(indexPath);
      String datName = basename(datExtractDir);
      String datPath = join(dirname(dirname(datExtractDir)), datName);
      String pakName = basename(indexPath);
      String pakExtractDir = join(datExtractDir, "pakExtracted", pakName);
      var pakBytes = await ByteDataWrapper.fromFile(indexPath);
      _indexPakContents(datPath, indexPath, pakExtractDir, pakBytes);
    }
    else if (indexPath.endsWith(".yax") || indexPath.endsWith(".xml")) {
      String pakExtractDir = dirname(indexPath);
      String pakName = basename(pakExtractDir);
      String datExtractDir = dirname(dirname(pakExtractDir));
      String pakPath = join(datExtractDir, pakName);
      String datName = basename(datExtractDir);
      String datPath = join(dirname(dirname(datExtractDir)), datName);

      if (indexPath.endsWith(".yax")) {
        var yaxBytes = await ByteDataWrapper.fromFile(indexPath);
        _indexYaxContents(datPath, pakPath, indexPath, yaxBytes);
      }
      else {
        String xml = await File(indexPath).readAsString();
        XmlDocument xmlDoc = XmlDocument.parse(xml);
        _indexXmlContents(datPath, pakPath, indexPath, xmlDoc.rootElement);
      }
    }
    else {
      print("Unknown file type: $indexPath");
    }
    
    int t2 = DateTime.now().millisecondsSinceEpoch;
    print("Found $foundXmlFiles xml files with ${indexedIds.length} IDs, ${indexedSceneStates.length} scene states and ${indexedCharNames.length} char names in ${(t2 - t1)~/1000}s");
  }

  Future<void> _indexAllIdsInDir(String dir) async {
    List<Future<void>> futures = [];
    var files = Directory(dir)
      .list(recursive: true)
      .where((f) => f is File && f.path.endsWith(".dat"));
    await for (var entry in files) {
      if (_stop)
        return;

      futures.add(_indexDatContents(entry.path));
    }
    await Future.wait(futures);
  }

  Future<void> _indexDatContents(String datPath) async {
    if (_stop)
      return;
    // List<Future<void>> futures = [];
    var fileName = basename(datPath);
    var datFolder = dirname(datPath);
    var datExtractDir = join(datFolder, "nier2blender_extracted", fileName);

    if (await Directory(datExtractDir).exists())
      await _indexDatExtractDir(datPath, datExtractDir);
    else
      await _indexDatFile(datPath, datExtractDir);

    // await Future.wait(futures);
  }

  Future<void> _indexDatExtractDir(String datPath, String datExtractDir) async {
    var pakFiles = (await getDatFiles(datExtractDir))
                    .where((f) => f.endsWith(".pak"));
    for (var pakFile in pakFiles) {
      var pakPath = join(datExtractDir, pakFile);
      var pakExtractDir = join(datExtractDir, "pakExtracted", basename(pakFile));
      var pakFileBytes = await ByteDataWrapper.fromFile(pakPath);
      await _indexPakContents(datPath, pakPath, pakExtractDir, pakFileBytes);
    }
  }

  Future<void> _indexDatFile(String datPath, String datExtractDir) async {
    await for (var fileData in extractDatFilesAsStream(datPath)) {
      if (_stop)
        return;
      if (!fileData.path.endsWith(".pak"))
        continue;
      var pakExtractDir = join(datExtractDir, "pakExtracted", basename(fileData.path));
      await _indexPakContents(datPath, fileData.path, pakExtractDir, fileData.bytes);
    }
  }

  Future<void> _indexPakContents(String datPath, String pakPath, String pakExtractPath, ByteDataWrapper bytes) async {
    if (_stop)
      return;
    List<Future<void>> futures = [];
    var pakInfoPath = join(pakExtractPath, "pakInfo.json");

    if (await File(pakInfoPath).exists())
      await _indexPakInfo(datPath, pakPath, pakExtractPath, pakInfoPath);
    else
      await _indexPakFiles(datPath, pakPath, pakExtractPath, bytes);

    await Future.wait(futures);
  }

  Future<void> _indexPakInfo(String datPath, String pakPath, String pakExtractPath, String pakInfoPath) async {var pakInfoJson = jsonDecode(await File(pakInfoPath).readAsString());
    var pakFiles = (pakInfoJson["files"] as List)
                    .map((f) => f["name"])
                    .toList();
    for (var yaxFile in pakFiles) {
      var yaxPath = join(pakExtractPath, yaxFile);
      var yaxBytes = await ByteDataWrapper.fromFile(yaxPath);
      await _indexYaxContents(datPath, pakPath, yaxPath, yaxBytes);
    }
  }

  Future<void> _indexPakFiles(String datPath, String pakPath, String pakExtractPath, ByteDataWrapper bytes) async {
    await for (var fileData in extractPakBytesAsStream(pakPath, bytes)) {
      if (_stop)
        return;
      await _indexYaxContents(datPath, pakPath, fileData.path, fileData.bytes);
    }
  }

  Future<void> _indexYaxContents(String datPath, String pakPath, String yaxPath, ByteDataWrapper bytes) async {
    if (_stop)
      return;
    var xmlPath = setExtension(yaxPath, ".xml");
    
    if (await File(xmlPath).exists()) {
      var xmlDoc = XmlDocument.parse(await File(xmlPath).readAsString());
      var xmlRoot = xmlDoc.rootElement;
      _indexXmlContents(datPath, pakPath, xmlPath, xmlRoot);
    }
    else {
      var xmlRoot = yaxToXml(bytes, includeAnnotations: false);
      _indexXmlContents(datPath, pakPath, xmlPath, xmlRoot);
    }
  }

  void _indexXmlContents(String datPath, String pakPath, String xmlPath, XmlElement root) {
    if (_stop)
      return;
    foundXmlFiles++;

    var rootName = root.getElement("name");
    if (rootName?.text == "SceneState" && root.getElement("node") != null) {
      _indexSceneState(root);
      return;
    }
    if (rootName?.text == "CharName" && root.getElement("text") != null) {
      _indexCharNames(root);
      return;
    }

    var hapIdEl = root.getElement("id");
    if (hapIdEl != null) {
      var hapId = int.parse(hapIdEl.text);
      _addIndexedData(hapId, IndexedIdData(hapId, "HAP", datPath, pakPath, xmlPath));
    }

    for (var action in root.findElements("action")) {
      var actionCode = int.parse(action.getElement("code")!.text);
      var actionId = int.parse(action.getElement("id")!.text);
      var actionName = action.getElement("name")!.text;
      actionName = tryToTranslate(actionName);
      _addIndexedData(actionId, IndexedActionIdData(actionId, datPath, pakPath, xmlPath, hashToStringMap[actionCode] ?? actionCode.toString(), actionName));

      for (var normal in action.findAllElements("normal")) {  // entities
        var normalLayouts = normal.getElement("layouts")!;
        for (var value in normalLayouts.findElements("value")) {
          var entityId = int.parse(value.childElements.first.text);
          var objId = value.getElement("objId")!.text;
          String? name;
          int? level;
          var aliasEl = value.getElement("alias");
          if (aliasEl != null)
            name = aliasEl.text;
          var paramsEl = value.getElement("param");
          if (paramsEl != null) {
            for (var param in paramsEl.findElements("value")) {
              var paramName = param.childElements.first.text;
              var paramBody = param.childElements.elementAt(2).text;
              if (paramName == "NameTag")
                name = paramBody;
              else if (paramName == "Lv")
                level = int.parse(paramBody);
            }
          }

          _addIndexedData(entityId, IndexedEntityIdData(entityId, datPath, pakPath, xmlPath, objId, actionId, name, level));
        }
      }
    }
  }

  void _addIndexedData(int id, IndexedIdData data) {
    var idList = indexedIds[id];
    if (idList == null) {
      idList = [];
      indexedIds[id] = idList;
    }
    idList.add(data);
  }

  void _indexSceneState(XmlElement root) {
    for (var child in root.getElement("node")!.findElements("child")) {
      var tag = child.getElement("tag")!.text;
      var value = child.getElement("value");
      String valueJap = "";
      String valueEng = "";
      if (value != null) {
        valueJap = value.text;
        valueEng = value.getAttribute("eng") ?? "";
      }
      indexedSceneStates[tag] = IndexedSceneStateData(tag, valueJap, valueEng);
    }
  }

  void _indexCharNames(XmlElement root) {
    // convert prop rows of hex to single string
    var hexStr = root.getElement("text")!.findElements("value")
      .map((t) => t.text)
      .join();
    var bytes = hex.decode(hexStr);
    var text = decodeString(bytes, StringEncoding.utf8);

    // parse lines into translations
    var lines = text.split("\n");
    lines = lines.sublist(1, lines.length - 1);
    String currentKey = "";
    List<MapEntry<String, String>> currentTranslations = [];
    for (var line in lines) {
      if (line.startsWith("  ")) {
        line = line.substring(2);
        var spaceIndex = line.indexOf(" ");
        var key = line.substring(0, spaceIndex);
        var val = line.substring(spaceIndex + 1);
        currentTranslations.add(MapEntry(key, val));
      }
      else {
        if (currentKey != "") {
          indexedCharNames[currentKey] = IndexedCharNameData(
            currentKey,
            Map.fromEntries(currentTranslations),
          );
        }
        currentKey = line.substring(1);
        currentTranslations = [];
      }
    }
    indexedCharNames[currentKey] = IndexedCharNameData(
      currentKey,
      Map.fromEntries(currentTranslations),
    );
  }
}
