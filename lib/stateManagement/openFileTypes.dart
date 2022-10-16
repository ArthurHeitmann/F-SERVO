
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../utils.dart';
import '../widgets/filesView/FileType.dart';
import 'FileHierarchy.dart';
import 'Property.dart';
import 'hasUuid.dart';
import 'miscValues.dart';
import 'undoable.dart';
import 'xmlProps/xmlProp.dart';

enum LoadingState {
  notLoaded,
  loading,
  loaded,
}

class OpenFileData extends ChangeNotifier with Undoable, HasUuid {
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
    else
      return TextFileData(name, path, secondaryName: secondaryName);
  }

  static FileType getFileType(String path) {
    if (path.endsWith(".xml"))
      return FileType.xml;
    else if (path == "preferences")
      return FileType.preferences;
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
  }

  Future<void> save() async {
    hasUnsavedChanges = false;
  }
  
@override
void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var content = OpenFileData(_name, _path);
    content._unsavedChanges = _unsavedChanges;
    content._loadingState = _loadingState;
    content.overrideUuidForUndoable(uuid);
    return content;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as OpenFileData;
    name = content._name;
    path = content._path;
    hasUnsavedChanges = content._unsavedChanges;
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
    _loadingState = LoadingState.loaded;
    notifyListeners();
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
    snapshot.overrideUuidForUndoable(uuid);
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
    _root = XmlProp.fromXml(doc.firstElementChild!, file: this, parentTags: []);
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

    _loadingState = LoadingState.loaded;
    notifyListeners();
  }

  Future<void> updatePakType() async {
    await updatePakInfoFileData(path, (fileData) => fileData["type"] = pakType!.value.toInt());
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
    snapshot.overrideUuidForUndoable(uuid);
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
    else
      _root = null;
  }
}
