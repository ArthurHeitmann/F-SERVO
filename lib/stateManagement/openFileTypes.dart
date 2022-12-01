
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../fileTypeUtils/audio/riffParser.dart';
import '../fileTypeUtils/audio/wemToWavConverter.dart';
import '../fileTypeUtils/smd/smdReader.dart';
import '../fileTypeUtils/smd/smdWriter.dart';
import '../fileTypeUtils/tmd/tmdReader.dart';
import '../fileTypeUtils/tmd/tmdWriter.dart';
import '../utils/utils.dart';
import '../widgets/filesView/FileType.dart';
import 'FileHierarchy.dart';
import 'HierarchyEntryTypes.dart';
import 'Property.dart';
import 'changesExporter.dart';
import 'hasUuid.dart';
import 'miscValues.dart';
import 'nestedNotifier.dart';
import 'openFilesManager.dart';
import 'otherFileTypes/FtbFileData.dart';
import 'otherFileTypes/McdData.dart';
import 'otherFileTypes/SmdFileData.dart';
import 'otherFileTypes/TmdFileData.dart';
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
  String? audioFilePath;
  ValueNestedNotifier<CuePointMarker> cuePoints = ValueNestedNotifier([]);
  bool cuePointsStartAt1 = false;
  Duration? duration;
  int samplesPerSec = 44100;
  int totalSamples = 0;
  List<int>? wavSamples;

  Future<void> load();

  void _readMeta(RiffFile riff) {
    samplesPerSec = riff.formatChunk.samplesPerSec;
    totalSamples = riff.dataChunk.samples.length ~/ riff.formatChunk.channels;
    duration = Duration(milliseconds: (totalSamples / samplesPerSec * 1000).round());
  }

  static const int _wavSamplesCount = 40000;
  void _parsePreviewSamples(RiffFile riff) {
    var rawSamples = riff.dataChunk.samples;
    int sampleCount = min(_wavSamplesCount, rawSamples.length);
    int samplesSize = rawSamples.length ~/ sampleCount;
    wavSamples = List.generate(sampleCount, (i) => rawSamples[i * samplesSize]);
  }

  void _readCuePoints(RiffFile riff) {
    List<RiffListLabelSubChunk> pendingLabels = [];
    for (var listChunk in riff.listChunks) {
      if (listChunk.chunkType != "adtl")
        continue;
      for (var subChunk in listChunk.subChunks) {
        if (subChunk is! RiffListLabelSubChunk)
          continue;
        pendingLabels.add(subChunk);
      }
    }
    if (pendingLabels.isNotEmpty) {
      int maxLabelCueIndex = pendingLabels.map((l) => l.cuePointIndex).reduce(max);
      // sometimes indexes start at 1, sometimes at 0
      cuePointsStartAt1 = maxLabelCueIndex == pendingLabels.length;
      int iOff = cuePointsStartAt1 ? -1 : 0;
      cuePoints.addAll(pendingLabels.map((l) {
        var cuePoint = riff.cueChunk!.points[l.cuePointIndex + iOff];
        return CuePointMarker(
          AudioSampleNumberProp(cuePoint.sampleOffset, samplesPerSec),
          StringProp(l.label),
          uuid
        );
      }));
    }
  }
}
class WavFileData with ChangeNotifier, HasUuid, AudioFileData {
  String path;

  WavFileData(this.path) {
    audioFilePath = path;
  }

  @override
  Future<void> load() async {
    var wavData = await RiffFile.fromFile(path);
    _readMeta(wavData);
    _parsePreviewSamples(wavData);
    _readCuePoints(wavData);
    notifyListeners();
  }
}
class WemFileData extends OpenFileData with AudioFileData {
  ValueNotifier<WavFileData?> overrideData = ValueNotifier(null);
  
  WemFileData(super.name, super.path, { super.secondaryName, Iterable<CuePointMarker>? cuePoints }) {
    if (cuePoints != null)
      this.cuePoints.addAll(cuePoints);
    this.cuePoints.addListener(_onCuePointsChanged);
  }

  @override
  Future<void> load() async {
    if (_loadingState != LoadingState.notLoaded && audioFilePath != null)
      return;
    _loadingState = LoadingState.loading;

    // extract wav
    audioFilePath = await wemToWav(path);

    var wavData = await RiffFile.fromFile(audioFilePath!);
    _readMeta(wavData);

    // rough wav samples
    _parsePreviewSamples(wavData);

    // cue points
    var wemData = await RiffFile.fromFile(path);
    _readCuePoints(wemData);

    hasUnsavedChanges = false;

    await super.load();
  }

  @override
  void dispose() {
    if (audioFilePath != null) {
      File(audioFilePath!).delete();
      audioFilePath = null;
    }
    wavSamples = null;
    cuePoints.dispose();
    super.dispose();
  }

  void _onCuePointsChanged() {
    hasUnsavedChanges = true;
    undoHistoryManager.onUndoableEvent();
  }

  Future<void> applyOverride() async {

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
