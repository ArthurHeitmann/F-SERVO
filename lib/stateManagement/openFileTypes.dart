
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../background/wemFilesIndexer.dart';
import '../fileTypeUtils/audio/bnkIO.dart';
import '../fileTypeUtils/audio/riffParser.dart';
import '../fileTypeUtils/audio/waiIO.dart';
import '../fileTypeUtils/audio/wavToWemConverter.dart';
import '../fileTypeUtils/smd/smdReader.dart';
import '../fileTypeUtils/smd/smdWriter.dart';
import '../fileTypeUtils/tmd/tmdReader.dart';
import '../fileTypeUtils/tmd/tmdWriter.dart';
import '../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../utils/utils.dart';
import '../widgets/filesView/FileType.dart';
import 'FileHierarchy.dart';
import 'HierarchyEntryTypes.dart';
import 'Property.dart';
import 'changesExporter.dart';
import 'events/statusInfo.dart';
import 'hasUuid.dart';
import 'miscValues.dart';
import 'nestedNotifier.dart';
import 'openFilesManager.dart';
import 'otherFileTypes/FtbFileData.dart';
import 'otherFileTypes/McdData.dart';
import 'otherFileTypes/SmdFileData.dart';
import 'otherFileTypes/TmdFileData.dart';
import 'otherFileTypes/audioResourceManager.dart';
import 'undoable.dart';
import 'xmlProps/xmlProp.dart';

enum LoadingState {
  notLoaded,
  loading,
  loaded,
}

abstract class OpenFileData extends ChangeNotifier with HasUuid, Undoable {
  late final FileType type;
  String _name;
  String? _secondaryName;
  String _path;
  bool _unsavedChanges = false;
  LoadingState _loadingState = LoadingState.notLoaded;
  LoadingState get loadingState => _loadingState;
  bool keepOpenAsHidden = false;
  final ChangeNotifier contentNotifier = ChangeNotifier();
  final ScrollController scrollController = ScrollController();

  OpenFileData(this._name, this._path, { String? secondaryName })
    : type = OpenFileData.getFileType(_path),
    _secondaryName = secondaryName;

  factory OpenFileData.from(String name, String path, { String? secondaryName }) {
    if (path.endsWith(".xml"))
      return XmlFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".rb"))
      return RubyFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".tmd"))
      return TmdFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".smd"))
      return SmdFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".mcd"))
      return McdFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".ftb"))
      return FtbFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".wem"))
      return WemFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".wsp"))
      return WspFileData(name, path, secondaryName: secondaryName);
    else if (path.endsWith(".wai"))
      return WaiFileData(name, path, secondaryName: secondaryName);
    else if (RegExp(r"\.bnk#p=\d+").hasMatch(path))
      return BnkFilePlaylistData(name, path, secondaryName: secondaryName);
    else
      return TextFileData(name, path, secondaryName: secondaryName);
  }

  static FileType getFileType(String path) {
    if (path.endsWith(".xml"))
      return FileType.xml;
    else if (path == "preferences")
      return FileType.preferences;
    else if (path.endsWith(".tmd"))
      return FileType.tmd;
    else if (path.endsWith(".smd"))
      return FileType.smd;
    else if (path.endsWith(".mcd"))
      return FileType.mcd;
    else if (path.endsWith(".ftb"))
      return FileType.ftb;
    else if (path.endsWith(".wem"))
      return FileType.wem;
    else if (path.endsWith(".wsp"))
      return FileType.wsp;
    else if (RegExp(r"\.bnk#p=\d+").hasMatch(path))
      return FileType.bnkPlaylist;
    else
      return FileType.text;
  }

  String get name => _name;
  String get displayName => _secondaryName == null ? _name : "$_name - $_secondaryName";
  String get path => _path;
  bool get hasUnsavedChanges => _unsavedChanges;

  set name(String value) {
    if (value == _name) return;
    _name = value;
    notifyListeners();
  }
  set secondaryName(String value) {
    if (value == _secondaryName) return;
    _secondaryName = value;
    notifyListeners();
  }
  set path(String value) {
    if (value == _path) return;
    _path = value;
    notifyListeners();
  }
  set hasUnsavedChanges(bool value) {
    if (value == _unsavedChanges) return;
    if (disableFileChanges) return;
    _unsavedChanges = value;
    notifyListeners();
  }

  Future<void> load() async {
    _loadingState = LoadingState.loaded;
    undoHistoryManager.onUndoableEvent();
    notifyListeners();
  }

  Future<void> save() async {
    hasUnsavedChanges = false;
  }
  
  @override
  void dispose() {
    contentNotifier.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

class TextFileData extends OpenFileData {
  String _text = "Loading...";

  TextFileData(super.name, super.path, { super.secondaryName });
  
  String get text => _text;

  set text(String value) {
    if (value == _text) return;
    _text = value;
    notifyListeners();
  }

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;
    _text = await File(path).readAsString();
    await super.load();
  }

  @override
  Future<void> save() async {
    await File(path).writeAsString(_text);
    hasUnsavedChanges = false;
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = TextFileData(_name, _path);
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot._text = _text;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as TextFileData;
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
    text = content._text;
  }
}

class XmlFileData extends OpenFileData {
  XmlProp? _root;
  XmlProp? get root => _root;
  NumberProp? pakType;

  XmlFileData(super.name, super.path, { super.secondaryName });

  void _onNameChange() {
    var xmlName = _root!.get("name")!.value.toString();

    secondaryName = xmlName;

    var hierarchyEntry = openHierarchyManager
                        .findRecWhere((entry) => entry is XmlScriptHierarchyEntry && entry.path == path) as XmlScriptHierarchyEntry?;
    if (hierarchyEntry != null)
      hierarchyEntry.hapName = xmlName;
  }

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;
    var text = await File(path).readAsString();
    var doc = XmlDocument.parse(text);
    _root = XmlProp.fromXml(doc.firstElementChild!, file: uuid, parentTags: []);
    _root!.addListener(notifyListeners);
    var nameProp = _root!.get("name");
    if (nameProp != null) {
      nameProp.value.addListener(_onNameChange);
      secondaryName = nameProp.value.toString();
    }
    
    var pakInfoFileData = await getPakInfoFileData(path);
    if (pakInfoFileData != null) {
      pakType = NumberProp(pakInfoFileData["type"], true);
      pakType!.addListener(updatePakType);
    }

    await super.load();
  }

  Future<void> updatePakType() async {
    await updatePakInfoFileData(path, (fileData) => fileData["type"] = pakType!.value.toInt());
    
    var pakDir = dirname(path);
    changedPakFiles.add(pakDir);
    await processChangedFiles();
  }

  @override
  Future<void> save() async {
    if (_root == null) {
      await super.save();
      return;
    }
    var doc = XmlDocument();
    doc.children.add(XmlDeclaration([XmlAttribute(XmlName("version"), "1.0"), XmlAttribute(XmlName("encoding"), "utf-8")]));
    doc.children.add(_root!.toXml());
    var xmlStr = "${doc.toXmlString(pretty: true, indent: '\t')}\n";
    await File(path).writeAsString(xmlStr);
    await super.save();
    changedXmlFiles.add(this);
  }

  @override
  void dispose() {
    _root?.removeListener(notifyListeners);
    _root?.dispose();
    _root?.get("name")?.value.removeListener(_onNameChange);
    pakType?.removeListener(updatePakType);
    pakType?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = XmlFileData(_name, _path);
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot._root = _root != null ? _root!.takeSnapshot() as XmlProp : null;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as XmlFileData;
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
    if (content._root != null)
      _root?.restoreWith(content._root as Undoable);
  }
}

class RubyFileData extends TextFileData {
  RubyFileData(super.name, super.path, { super.secondaryName });

  @override
  Future<void> save() async {
    await super.save();
    changedRbFiles.add(path);
  }
}

class TmdFileData extends OpenFileData {
  TmdData? tmdData;

  TmdFileData(super.name, super.path, { super.secondaryName });

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;

    var tmdEntries = await readTmdFile(path);
    tmdData?.dispose();
    tmdData = TmdData.from(tmdEntries, basenameWithoutExtension(path));
    tmdData!.fileChangeNotifier.addListener(() {
      hasUnsavedChanges = true;
    });

    await super.load();
  }

  @override
  Future<void> save() async {
    await saveTmd(tmdData!.toEntries(), path);

    var datDir = dirname(path);
    changedDatFiles.add(datDir);

    await super.save();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = TmdFileData(_name, _path);
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot.tmdData = tmdData?.takeSnapshot() as TmdData?;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as TmdFileData;
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
    if (content.tmdData != null)
      tmdData?.restoreWith(content.tmdData as Undoable);
  }

  @override
  void dispose() {
    tmdData?.dispose();
    super.dispose();
  }
}

class SmdFileData extends OpenFileData {
  SmdData? smdData;

  SmdFileData(super.name, super.path, { super.secondaryName });

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;

    var smdEntries = await readSmdFile(path);
    smdData?.dispose();
    smdData = SmdData.from(smdEntries, basenameWithoutExtension(path));
    smdData!.fileChangeNotifier.addListener(() {
      hasUnsavedChanges = true;
    });

    await super.load();
  }

  @override
  Future<void> save() async {
    await saveSmd(smdData!.toEntries(), path);

    var datDir = dirname(path);
    changedDatFiles.add(datDir);

    await super.save();
  }

  @override
  void dispose() {
    smdData?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = SmdFileData(_name, _path);
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot.smdData = smdData?.takeSnapshot() as SmdData?;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as SmdFileData;
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
    if (content.smdData != null)
      smdData?.restoreWith(content.smdData as Undoable);
  }
}

class McdFileData extends OpenFileData {
  McdData? mcdData;

  McdFileData(super.name, super.path, { super.secondaryName });

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;

    mcdData?.dispose();
    mcdData = await McdData.fromMcdFile(uuid, path);

    await super.load();
  }

  @override
  Future<void> save() async {
    await mcdData?.save();
    var datDir = dirname(path);
    changedDatFiles.add(datDir);
    await super.save();
  }

  @override
  void dispose() {
    mcdData?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = McdFileData(_name, _path);
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot.mcdData = mcdData?.takeSnapshot() as McdData?;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as McdFileData;
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
    if (content.mcdData != null)
      mcdData?.restoreWith(content.mcdData as Undoable);
  }
}

class FtbFileData extends OpenFileData {
  FtbData? ftbData;

  FtbFileData(super.name, super.path, { super.secondaryName });

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;

    ftbData = await FtbData.fromFtbFile(path);
    await ftbData!.extractTextures();

    await super.load();
  }

  @override
  Future<void> save() async {
    await ftbData?.save();
    var datDir = dirname(path);
    changedDatFiles.add(datDir);
    await super.save();
  }

  @override
  void dispose() {
    ftbData?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    return this;
  }

  @override
  void restoreWith(Undoable snapshot) {
    // nothing to do
  }
}

class CuePointMarker with HasUuid, Undoable {
  final AudioSampleNumberProp sample;
  final StringProp name;
  final OpenFileId file;

  CuePointMarker(this.sample, this.name, this.file) {
    sample.addListener(_onChanged);
    name.addListener(_onChanged);
  }

  void dispose() {
    sample.dispose();
    name.dispose();
  }

  void _onChanged() {
    var file = areasManager.fromId(this.file);
    if (file == null)
      return;
    file.hasUnsavedChanges = true;
    undoHistoryManager.onUndoableEvent();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = CuePointMarker(sample.takeSnapshot() as AudioSampleNumberProp, name.takeSnapshot() as StringProp, file);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as CuePointMarker;
    sample.restoreWith(content.sample);
    name.restoreWith(content.name);
  }
}
mixin AudioFileData on ChangeNotifier, HasUuid {
  AudioResource? resource;
  ValueNestedNotifier<CuePointMarker> cuePoints = ValueNestedNotifier([]);
  bool cuePointsStartAt1 = false;
  abstract String name;

  Future<void> load();

  // void _readCuePoints(RiffFile riff) {
  //   List<RiffListLabelSubChunk> pendingLabels = [];
  //   if (riff.labelsList != null) {
  //     for (var subChunk in riff.labelsList!.subChunks) {
  //       if (subChunk is! RiffListLabelSubChunk)
  //         continue;
  //       if (subChunk.chunkId != "labl")
  //         continue;
  //       pendingLabels.add(subChunk);
  //     }
  //   }
  //   if (pendingLabels.isNotEmpty) {
  //     int maxLabelCueIndex = pendingLabels.map((l) => l.cuePointIndex).reduce(max);
  //     // sometimes indexes start at 1, sometimes at 0
  //     cuePointsStartAt1 = maxLabelCueIndex == pendingLabels.length;
  //     int iOff = cuePointsStartAt1 ? -1 : 0;
  //     cuePoints.clear();
  //     cuePoints.addAll(pendingLabels.map((l) {
  //       var cuePoint = riff.cues!.points[l.cuePointIndex + iOff];
  //       return CuePointMarker(
  //         AudioSampleNumberProp(cuePoint.sampleOffset, samplesPerSec),
  //         StringProp(l.label),
  //         uuid
  //       );
  //     }));
  //   }
  // }
}
class WavFileData with ChangeNotifier, HasUuid, AudioFileData {
  @override
  String name;
  String path;

  WavFileData(this.path) : name = basename(path);

  @override
  Future<void> load() async {
    resource = await audioResourcesManager.getAudioResource(path);
    notifyListeners();
  }
}
class WemFileData extends OpenFileData with AudioFileData {
  ValueNotifier<WavFileData?> overrideData = ValueNotifier(null);
  ChangeNotifier onOverrideApplied = ChangeNotifier();
  bool isReplacing = false;
  Set<int> relatedBnkPlaylistIds = {};
  String? bgmBnkPath;
  
  WemFileData(super.name, super.path, { super.secondaryName, Iterable<CuePointMarker>? cuePoints }) {
    if (cuePoints != null)
      this.cuePoints.addAll(cuePoints);
    this.cuePoints.addListener(_onCuePointsChanged);
  }

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded && resource != null)
      return;
    _loadingState = LoadingState.loading;

    // extract wav
    await resource?.dispose();
    resource = await audioResourcesManager.getAudioResource(path);

    // var wavData = await RiffFile.fromFile(resource!.wavPath);
    // _readMeta(wavData);

    // // rough wav samples
    // _parsePreviewSamples(wavData);

    // // cue points
    // var wemData = await RiffFile.fromFile(path);
    // _readCuePoints(wemData);

    // related bnk playlists
    var waiRes = areasManager.hiddenArea.whereType<WaiFileData>();
    if (waiRes.isNotEmpty) {
      var wai = waiRes.first;
      bgmBnkPath = wai.bgmBnkPath;
      if (wai.wemIdsToBnkPlaylists.isNotEmpty) {
        var wemId = int.parse(RegExp(r"(\d+)\.wem").firstMatch(name)!.group(1)!);
        relatedBnkPlaylistIds.addAll(wai.wemIdsToBnkPlaylists[wemId] ?? []);
      }
    }

    hasUnsavedChanges = false;

    await super.load();
  }

  @override
  Future<void> save() async {
    await _saveCuePoints();

    var wai = areasManager.hiddenArea.whereType<WaiFileData>().first;
    var wemId = RegExp(r"(\d+)\.wem").firstMatch(name)!.group(1)!;
    wai.pendingPatches.add(WemPatch(path, int.parse(wemId)));

    await super.save();
  }

  @override
  void dispose() {
    if (resource != null) {
      resource!.dispose();
      resource = null;
    }
    if (overrideData.value != null) {
      overrideData.value!.dispose();
      overrideData.value = null;
    }
    cuePoints.dispose();
    super.dispose();
  }

  Future<void> _saveCuePoints() async {

    var riff = await RiffFile.fromFile(path);

    var iOff = cuePointsStartAt1 ? 1 : 0;
    var cueChunk = CueChunk(
      cuePoints.length,
      List.generate(cuePoints.length, (i) => CuePoint(
        i + iOff, cuePoints[i].sample.value, "data", 0, 0, cuePoints[i].sample.value
      ))
    );
    int markersSize = 0;
    var adtlMarkers = List.generate(cuePoints.length, (i) {
      int chunkSize = 4 + cuePoints[i].name.value.length + 1;
      markersSize += chunkSize + 8 + chunkSize % 2;
      return RiffListLabelSubChunk(
        "labl", chunkSize, i + iOff, cuePoints[i].name.value
      );
    });
    var adtListChunk = RiffListChunk("adtl", adtlMarkers, 4 + markersSize);

    var cuesIndex = riff.chunks.indexWhere((c) => c is CueChunk);
    if (cuesIndex != -1)
      riff.chunks[cuesIndex] = cueChunk;
    else
      riff.chunks.insert(riff.chunks.length - 1, cueChunk);

    var adtlIndex = riff.chunks.indexWhere((c) => c is RiffListChunk && c.chunkType == "adtl");
    if (adtlIndex != -1)
      riff.chunks[adtlIndex] = adtListChunk;
    else
      riff.chunks.insert(riff.chunks.length - 1, adtListChunk);

    var fileSize = riff.size;
    riff.header.size = fileSize - 8;
    var newBytes = ByteDataWrapper.allocate(fileSize);
    riff.write(newBytes);
    await File(path).writeAsBytes(newBytes.buffer.asUint8List());
  }

  void _onCuePointsChanged() {
    hasUnsavedChanges = true;
    undoHistoryManager.onUndoableEvent();
  }

  Future<void> applyOverride() async {
    if (overrideData.value == null)
      throw Exception("No override data");
    
    isReplacing = true;
    notifyListeners();

    await backupFile(path);
    var wav = overrideData.value!;
    await wavToWem(wav.path, path, basename(path).contains("BGM"));
    overrideData.value = null;

    // reload
    _loadingState = LoadingState.notLoaded;
    await audioResourcesManager.reloadAudioResource(resource!);
    // await load();

    hasUnsavedChanges = true;
    isReplacing = false;
    notifyListeners();
    onOverrideApplied.notifyListeners();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = WemFileData(
      _name, _path, secondaryName: _secondaryName,
      cuePoints: cuePoints.takeSnapshot() as ValueNestedNotifier<CuePointMarker>
    );
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as WemFileData;
    name = content._name;
    path = content._path;
    cuePoints.restoreWith(content.cuePoints);
    hasUnsavedChanges = content._unsavedChanges;
  }
}

class WspFileData extends OpenFileData {
  List<WemFileData> wems = [];

  WspFileData(super.name, super.path, { super.secondaryName });

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;

    var wspHierarchyEntry = openHierarchyManager.findRecWhere((e) => e is WspHierarchyEntry && e.path == path);
    if (wspHierarchyEntry == null) {
      showToast("WSP hierarchy entry not found");
      throw Exception("WSP hierarchy entry not found for $path");
    }
    wems = wspHierarchyEntry
      .map((e) => e as WemHierarchyEntry)
      .map((e) => WemFileData(
        e.name.value,
        e.path,
      ))
      .toList();

    await Future.wait(wems.map((w) => w.load()));

    await super.load();
  }

  @override
  void dispose() {
    for (var wem in wems)
      wem.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = WspFileData(_name, _path);
    snapshot.wems = wems.map((w) => w.takeSnapshot() as WemFileData).toList();
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as WspFileData;
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
    for (var i = 0; i < wems.length; i++)
      wems[i].restoreWith(content.wems[i]);
  }
}

class WaiFileData extends OpenFileData {
  WaiFile? wai;
  Set<WemPatch> pendingPatches = {};
  String? bgmBnkPath;
  Map<int, Set<int>> wemIdsToBnkPlaylists = {};

  WaiFileData(super.name, super.path, { super.secondaryName });

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;
    
    var bytes = await ByteDataWrapper.fromFile(path);
    wai = WaiFile.read(bytes);

    var bnkPath = join(dirname(path), "bgm", "BGM.bnk");
    if (await File(bnkPath).exists()) {
      bgmBnkPath = bnkPath;
      var bnk = BnkFile.read(await ByteDataWrapper.fromFile(bnkPath));
      var hirc = bnk.chunks.whereType<BnkHircChunk>().first;
      var hircData = hirc.chunks.whereType<BnkHircChunkBase>().toList();
      Map<int, BnkHircChunkBase> hircMap = {
        for (var hirc in hirc.chunks.whereType<BnkHircChunkBase>())
          hirc.uid: hirc
      };
      var playlists = hircData.whereType<BnkMusicPlaylist>();
      Map<int, Set<int>> playlistIdsToSources = {
        for (var playlist in playlists)
          playlist.uid: playlist.playlistItems
            .map((e) => e.segmentId)
            .where((e) => e != 0)
            .map((e) => (hircMap[e] as BnkMusicSegment).musicParams.childrenList.ulChildIDs)
            .expand((e) => e)
            .map((e) => (hircMap[e] as BnkMusicTrack).playlists)
            .expand((e) => e)
            .map((e) => e.sourceID)
            .toSet()
      };
      wemIdsToBnkPlaylists.clear();
      for (var playlistKV in playlistIdsToSources.entries) {
        for (var sourceId in playlistKV.value) {
          if (!wemIdsToBnkPlaylists.containsKey(sourceId))
            wemIdsToBnkPlaylists[sourceId] = {};
          wemIdsToBnkPlaylists[sourceId]!.add(playlistKV.key);
        }
      }
    } else {
      showToast("BGM.bnk not found");
    }

    await super.load();
  }

  @override
  void dispose() {
    wai = null;
    super.dispose();
  }

  @override
  Future<void> save() async {
    var fileSize = wai!.size;
    var bytes = ByteDataWrapper.allocate(fileSize);
    wai!.write(bytes);
    await backupFile(path);
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
  }

  Future<void> processPendingPatches() async {
    if (pendingPatches.isEmpty)
      return;
    // update WSPs & wai data
    var exportDir = join(dirname(path), "stream");
    await wai!.patchWems(pendingPatches.toList(), exportDir);
    pendingPatches.clear();

    // write wai
    await save();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = WaiFileData(_name, _path);
    snapshot.wai = wai;
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as WaiFileData;
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
    // wai = content.wai;
  }
}

class BnkTrackClip with HasUuid, Undoable {
  final OpenFileId file;
  final BnkPlaylist srcPlaylist;
  final int sourceId;
  final NumberProp xOff;
  final NumberProp beginTrim;
  final NumberProp endTrim;
  final NumberProp srcDuration;
  AudioResource? resource;
  BnkTrackClip(this.file, this.srcPlaylist, this.sourceId, this.xOff, this.beginTrim, this.endTrim, this.srcDuration) {
    _setupListeners();
  }
  BnkTrackClip.fromPlaylist(this.file, this.srcPlaylist) :
    sourceId = srcPlaylist.sourceID,
    xOff = NumberProp(srcPlaylist.fPlayAt, false),
    beginTrim = NumberProp(srcPlaylist.fBeginTrimOffset, false),
    endTrim = NumberProp(srcPlaylist.fEndTrimOffset, false),
    srcDuration = NumberProp(srcPlaylist.fSrcDuration, false) {
    _setupListeners();
  }

  void _setupListeners() {
    xOff.addListener(_onPropChanged);
    beginTrim.addListener(_onPropChanged);
    endTrim.addListener(_onPropChanged);
    srcDuration.addListener(_onPropChanged);
  }
  void _onPropChanged() {
    areasManager.fromId(file)!.hasUnsavedChanges = true;
  }
  
  void dispose() {
    xOff.dispose();
    beginTrim.dispose();
    endTrim.dispose();
    srcDuration.dispose();
  }

  void applyTo(BnkPlaylist newPlaylist) {
    newPlaylist.fPlayAt = xOff.value.toDouble();
    newPlaylist.fBeginTrimOffset = beginTrim.value.toDouble();
    newPlaylist.fEndTrimOffset = endTrim.value.toDouble();
    newPlaylist.fSrcDuration = srcDuration.value.toDouble();
  }

  Future<void> loadResource() async {
    var wemPath = wemFilesLookup.lookup[sourceId];
    if (wemPath == null)
      return;
    resource = await audioResourcesManager.getAudioResource(wemPath);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkTrackClip(file, srcPlaylist, sourceId, xOff.takeSnapshot() as NumberProp, beginTrim.takeSnapshot() as NumberProp, endTrim.takeSnapshot() as NumberProp, srcDuration.takeSnapshot() as NumberProp);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkTrackClip;
    xOff.restoreWith(content.xOff);
    beginTrim.restoreWith(content.beginTrim);
    endTrim.restoreWith(content.endTrim);
    srcDuration.restoreWith(content.srcDuration);
  }
}
class BnkTrackData with HasUuid, Undoable {
  final OpenFileId file;
  final BnkMusicTrack srcTrack;
  final List<BnkTrackClip> clips;
  final ValueNotifier<bool> hasSourceChanged = ValueNotifier(false);
  BnkTrackData(this.file, this.srcTrack, this.clips);
  BnkTrackData.fromTrack(this.file, this.srcTrack) :
    clips = srcTrack.playlists.map((s) => BnkTrackClip.fromPlaylist(file, s)).toList();
  
  void dispose() {
    for (var clip in clips)
      clip.dispose();
    hasSourceChanged.dispose();
  }

  void applyTo(BnkMusicTrack newTrack) {
    if (clips.length != newTrack.playlists.length)
      throw Exception("Can't apply track data to a different track");
    for (var i = 0; i < clips.length; i++)
      clips[i].applyTo(newTrack.playlists[i]);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkTrackData(file, srcTrack, clips.map((c) => c.takeSnapshot() as BnkTrackClip).toList());
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkTrackData;
    for (var i = 0; i < clips.length; i++)
      clips[i].restoreWith(content.clips[i]);
  }
  
  Future<void> updateDuration() async {
    if (!srcTrack.sources.every((s) => s.sourceID == srcTrack.sources.first.sourceID))
      throw Exception("Can't update duration of a track with multiple sources");
    var srcId = srcTrack.sources.first.sourceID;
    var wemPath = wemFilesLookup.lookup[srcId];
    if (wemPath == null)
      return;
    var wemBytes = await ByteDataWrapper.fromFile(wemPath);
    var wemRiff = RiffFile.onlyFormat(wemBytes);
    var riffFormat = wemRiff.format;
    double duration;
    if (riffFormat is WemFormatChunk) {
      duration = riffFormat.numSamples / riffFormat.samplesPerSec;
    } else {
      print("Unsupported format chunk in $wemPath");
      return;
    }
    for (var clip in clips) {
      var newDuration = duration * 1000;
      if (newDuration == clip.srcDuration.value)
        continue;
      clip.srcDuration.value = newDuration;
      if (clip.beginTrim.value > clip.srcDuration.value + clip.endTrim.value) {
        clip.beginTrim.value = 0;
        messageLog.add("Warning: Set clip begin to 0 on ${basename(wemPath)}");
      }
      if (clip.srcDuration.value + clip.endTrim.value < clip.beginTrim.value) {
        clip.endTrim.value = 0;
        messageLog.add("Warning: Set clip end to 0 on ${basename(wemPath)}");
      }
      hasSourceChanged.value = true;
    }
  }
}
enum BnkMarkerRole {
  entryCue, exitCue, custom
}
class BnkSegmentMarker with HasUuid, Undoable {
  final OpenFileId file;
  final BnkMusicMarker srcMarker;
  final NumberProp pos;
  final BnkMarkerRole role;
  String get name => srcMarker.pMarkerName ?? "";
  BnkSegmentMarker(this.file, this.srcMarker, this.pos, this.role) {
    _setupListeners();
  }
  BnkSegmentMarker.fromMarker(this.file, this.srcMarker, List<BnkMusicMarker> markers) :
    pos = NumberProp(srcMarker.fPosition, false),
    role = markers.first == srcMarker
      ? BnkMarkerRole.entryCue
      : markers.last == srcMarker
        ? BnkMarkerRole.exitCue
        : BnkMarkerRole.custom {
    _setupListeners();
  }

  void _setupListeners() {
    pos.addListener(_onPropChanged);
  }
  void _onPropChanged() {
    areasManager.fromId(file)!.hasUnsavedChanges = true;
  }
  
  void dispose() {
    pos.dispose();
  }

  void applyTo(BnkMusicMarker newMarker) {
    newMarker.fPosition = pos.value.toDouble();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkSegmentMarker(file, srcMarker, pos.takeSnapshot() as NumberProp, role);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkSegmentMarker;
    pos.restoreWith(content.pos);
  }
}
class BnkSegmentData with HasUuid, Undoable {
  final OpenFileId file;
  final BnkMusicSegment srcSegment;
  final NumberProp duration;
  final List<BnkTrackData> tracks;
  final List<BnkSegmentMarker> markers;
  BnkSegmentData(this.file, this.srcSegment, this.duration, this.tracks, this.markers) {
    _setupListeners();
  }
  BnkSegmentData.fromSegment(this.file, this.srcSegment, Map<int, BnkHircChunkBase> hircMap) :
    duration = NumberProp(srcSegment.fDuration, false),
    tracks = srcSegment.musicParams.childrenList.ulChildIDs.map((id) => 
      BnkTrackData.fromTrack(file, hircMap[id] as BnkMusicTrack)).toList(),
    markers = srcSegment.wwiseMarkers.map((m) => BnkSegmentMarker.fromMarker(file, m, srcSegment.wwiseMarkers)).toList() {
    _setupListeners();
  }

  void _setupListeners() {
    duration.addListener(_onPropChanged);
  }
  void _onPropChanged() {
    areasManager.fromId(file)!.hasUnsavedChanges = true;
  }
  
  void dispose() {
    duration.dispose();
    for (var t in tracks)
      t.dispose();
    for (var m in markers)
      m.dispose();
  }

  void applyTo(BnkMusicSegment newSegment, Map<int, BnkHircChunkBase> hircMap) {
    if (markers.length != srcSegment.wwiseMarkers.length)
      throw Exception("Cannot apply segment with different number of markers");
    if (tracks.length != srcSegment.musicParams.childrenList.ulChildIDs.length)
      throw Exception("Cannot apply segment with different number of tracks");
    if (markers.length >= 2) {
      var minMarkerPos = markers.map((m) => m.pos.value).reduce(min);
      var maxMarkerPos = markers.map((m) => m.pos.value).reduce(max);
      newSegment.fDuration = maxMarkerPos - minMarkerPos.toDouble();
    }
    for (var i = 0; i < markers.length; i++) {
      var newMarker = newSegment.wwiseMarkers[i];
      markers[i].applyTo(newMarker);
    }
    for (var i = 0; i < tracks.length; i++) {
      var newTrack = hircMap[srcSegment.musicParams.childrenList.ulChildIDs[i]] as BnkMusicTrack;
      tracks[i].applyTo(newTrack);
    }
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkSegmentData(
      file,
      srcSegment,
      duration.takeSnapshot() as NumberProp,
      tracks.map((t) => t.takeSnapshot() as BnkTrackData).toList(),
      markers.map((m) => m.takeSnapshot() as BnkSegmentMarker).toList()
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkSegmentData;
    duration.restoreWith(content.duration);
    for (var i = 0; i < tracks.length; i++)
      tracks[i].restoreWith(content.tracks[i]);
    for (var i = 0; i < markers.length; i++)
      markers[i].restoreWith(content.markers[i]);
  }
}
enum BnkPlaylistChildResetType {
  none(-1, "None"),
  continuousSequence(0, "Continuous Sequence"),
  randomSequence(1, "Step Sequence"),
  continuousRandom(2, "Continuous Random"),
  stepRandom(3, "Step Random");
  final int value;
  final String name;
  const BnkPlaylistChildResetType(this.value, this.name);
  static BnkPlaylistChildResetType fromValue(int value) {
    for (var t in values)
      if (t.value == value)
        return t;
    return none;
  }
}
class BnkPlaylistChild with HasUuid, Undoable {
  final OpenFileId file;
  final BnkPlaylistItem srcItem;
  final int index;
  final List<BnkPlaylistChild> children;
  final BnkSegmentData? segment;
  final String loops;
  final BnkPlaylistChildResetType resetType;
  final List<int> appliesTo;  // playlist IDs
  BnkPlaylistChild(this.file, this.srcItem, this.index, this.children, this.segment, this.loops, this.resetType)
    : appliesTo = [];
  BnkPlaylistChild.fromPlaylistItem(this.file, this.srcItem, this.index, Map<int, BnkHircChunkBase> hircMap) :
    children = [],
    segment = srcItem.segmentId != 0 ? BnkSegmentData.fromSegment(file, hircMap[srcItem.segmentId] as BnkMusicSegment, hircMap) : null,
    loops = srcItem.loop == 0 ? "Infinite" : srcItem.loop.toString(),
    resetType = BnkPlaylistChildResetType.fromValue(srcItem.eRSType),
    appliesTo = [srcItem.playlistItemId];
  
  List<BnkPlaylistItem> parseChildren(int curIndex, List<BnkPlaylistItem> remainingItems, Map<int, BnkHircChunkBase> hircMap, List<BnkPlaylistChild> parsedItems) {
    var remaining = remainingItems;
    remaining = remaining.sublist(1);
    curIndex++;
    for (int i = 0; i < srcItem.numChildren; i++) {
      var child = BnkPlaylistChild.fromPlaylistItem(file, remaining.first, curIndex, hircMap);
      int prevLength = remaining.length;
      remaining = child.parseChildren(curIndex, remaining, hircMap, parsedItems);
      curIndex += prevLength - remaining.length;
      children.add(child);
      parsedItems.add(child);
    }
    return remaining;
  }

  static BnkPlaylistChild parsePlaylist(OpenFileId file, BnkMusicPlaylist srcPlaylist, Map<int, BnkHircChunkBase> hircMap) {
    var root = BnkPlaylistChild.fromPlaylistItem(file, srcPlaylist.playlistItems.first, 0, hircMap);
    var remaining = root.parseChildren(0, srcPlaylist.playlistItems, hircMap, []);
    if (remaining.isNotEmpty)
      throw Exception("Failed to parse playlist");
    return root;
  }

  void dispose() {
    segment?.dispose();
    for (var c in children)
      c.dispose();
  }
  
  void applyTo(List<BnkPlaylistItem> newItems, Map<int, BnkHircChunkBase> hircMap) {
    var newItem = newItems[index];
    if (srcItem.playlistItemId != newItem.playlistItemId)
      throw Exception("Playlist item ID mismatch");
    if (children.length != newItem.numChildren)
      throw Exception("Number of children mismatch");
    if ((segment == null) != (newItem.segmentId == 0))
      throw Exception("Segment mismatch");
    if (segment != null) {
      var newSegment = hircMap[newItem.segmentId] as BnkMusicSegment;
      segment!.applyTo(newSegment, hircMap);
    }
    for (var i = 0; i < children.length; i++) {
      children[i].applyTo(newItems, hircMap);
    }
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkPlaylistChild(file, srcItem, index, children.map((c) => c.takeSnapshot() as BnkPlaylistChild).toList(), segment?.takeSnapshot() as BnkSegmentData?, loops, resetType);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkPlaylistChild;
    for (var i = 0; i < children.length; i++)
      children[i].restoreWith(content.children[i]);
    if (segment != null)
      segment!.restoreWith(content.segment!);
  }

  Future<void> updateTrackDurations() async {
    List<BnkPlaylistChild> pending = [this];
    List<Future<void>> futures = [];
    while (pending.isNotEmpty) {
      var child = pending.removeAt(0);
      pending.addAll(child.children);
      if (child.segment != null) {
        for (var track in child.segment!.tracks)
          futures.add(track.updateDuration());
      }
    }
    await Future.wait(futures);
  }
}
class BnkFilePlaylistData extends OpenFileData {
  final int playlistId;
  BnkMusicPlaylist? srcPlaylist;
  BnkPlaylistChild? rootChild;

  BnkFilePlaylistData(String name, String path, { super.secondaryName }) :
    playlistId = int.parse(RegExp(r"\.bnk#p=(\d+)$").firstMatch(name)!.group(1)!),
    super(name, path);

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded)
      return;
    _loadingState = LoadingState.loading;

    var bytes = await ByteDataWrapper.fromFile(path.split("#").first);
    var bnk = BnkFile.read(bytes);
    var hircChunk = bnk.chunks.whereType<BnkHircChunk>().first;
    Map<int, BnkHircChunkBase> hircMap = {
      for (var hirc in hircChunk.chunks.whereType<BnkHircChunkBase>())
        hirc.uid: hirc
    };
    srcPlaylist = hircChunk.chunks
      .whereType<BnkMusicPlaylist>()
      .firstWhere((p) => p.uid == playlistId);
    rootChild = BnkPlaylistChild.parsePlaylist(uuid, srcPlaylist!, hircMap);
    await rootChild!.updateTrackDurations();

    await super.load();
  }

  @override
  Future<void> save() async {
    if (_loadingState != LoadingState.loaded)
      return;
    
    var bnkPath = path.split("#").first;
    var bytes = await ByteDataWrapper.fromFile(bnkPath);
    var bnk = BnkFile.read(bytes);
    var hircChunk = bnk.chunks.whereType<BnkHircChunk>().first;
    Map<int, BnkHircChunkBase> hircMap = {
      for (var hirc in hircChunk.chunks.whereType<BnkHircChunkBase>())
        hirc.uid: hirc
    };
    var newPlaylist = hircMap[playlistId] as BnkMusicPlaylist;
    rootChild!.applyTo(newPlaylist.playlistItems, hircMap);
    bytes = ByteDataWrapper.allocate(bytes.length);
    bnk.write(bytes);
    await backupFile(bnkPath);
    await File(bnkPath).writeAsBytes(bytes.buffer.asUint8List());

    await super.save();
  }

  @override
  void dispose() {
    super.dispose();
    rootChild?.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = BnkFilePlaylistData(_name, _path);
    snapshot.rootChild = rootChild?.takeSnapshot() as BnkPlaylistChild?;
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._loadingState = _loadingState;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as BnkFilePlaylistData;
    rootChild?.restoreWith(content.rootChild!);
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
  }
}
