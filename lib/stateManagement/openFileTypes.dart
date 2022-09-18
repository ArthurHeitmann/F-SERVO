
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../utils.dart';
import '../widgets/filesView/FileType.dart';
import 'undoable.dart';
import 'xmlProp.dart';

class OpenFileData extends ChangeNotifier with Undoable {
  String _uuid;
  String _name;
  String _path;
  bool _unsavedChanges = false;
  bool _isLoaded = false;
  final ScrollController scrollController = ScrollController();
  late final FileType type;

  OpenFileData(this._name, this._path)
    : type = OpenFileData.getFileType(_path),
      _uuid = uuidGen.v1();

  factory OpenFileData.from(String name, String path) {
    if (path.endsWith(".xml"))
      return XmlFileData(name, path);
    else
      return TextFileData(name, path);
  }

  static FileType getFileType(String path) {
    if (path.endsWith(".xml"))
      return FileType.xml;
    else
      return FileType.text;
  }

  String get uuid => _uuid;
  String get name => _name;
  String get path => _path;
  bool get hasUnsavedChanges => _unsavedChanges;

  set name(String value) {
    if (value == _name) return;
    _name = value;
    notifyListeners();
  }
  set path(String value) {
    if (value == _path) return;
    _path = value;
    notifyListeners();
  }
  set hasUnsavedChanges(bool value) {
    if (value == _unsavedChanges) return;
    _unsavedChanges = value;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoaded = true;
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
    content._isLoaded = _isLoaded;
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

  void overrideUuidForUndoable(String uuid) {
    _uuid = uuid;
  }
}

class TextFileData extends OpenFileData {
  String _text = "Loading...";

  TextFileData(super.name, super.path);
  
  String get text => _text;

  set text(String value) {
    if (value == _text) return;
    _text = value;
    notifyListeners();
  }

  @override
  Future<void> load() async {
    if (_isLoaded) return;
    _text = await File(path).readAsString();
    _isLoaded = true;
    notifyListeners();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = TextFileData(_name, _path);
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._isLoaded = _isLoaded;
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

  XmlFileData(super.name, super.path);

  XmlProp? get root => _root;
  
  @override
  Future<void> load() async {
    if (_isLoaded) return;
    var text = await File(path).readAsString();
    var doc = XmlDocument.parse(text);
    _root = XmlProp.fromXml(doc.firstElementChild!, file: this);
    _root!.addListener(notifyListeners);
    _isLoaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _root?.removeListener(notifyListeners);
    _root?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = XmlFileData(_name, _path);
    snapshot._unsavedChanges = _unsavedChanges;
    snapshot._isLoaded = _isLoaded;
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
