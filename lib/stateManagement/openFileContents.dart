
import 'dart:io';
import 'package:flutter/material.dart';

import '../widgets/filesView/FileType.dart';
import 'nestedNotifier.dart';
import 'openFilesManager.dart';
import 'undoable.dart';

class FileContent extends ChangeNotifier with Undoable {
  final OpenFileData id;
  final ScrollController scrollController = ScrollController();
  final Key key;
  bool _isLoaded = false;

  FileContent(this.id) : key = PageStorageKey(id.uuid);

  Future<void> load() async {
    _isLoaded = true;
  }

  factory FileContent.fromFile(OpenFileData file) {
    switch (file.type) {
      case FileType.text:
        return FileTextContent(file);
      default:
        throw UnsupportedError("File type ${file.type} is not supported");
    }
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as FileContent;
    // _isLoaded = content._isLoaded;
  }
  
  @override
  Undoable takeSnapshot() {
    var content = FileContent(id);
    content._isLoaded = _isLoaded;
    return content;
  }
}

class FileTextContent extends FileContent {
  String _text = "Loading...";

  FileTextContent(super.id);

  @override
  Future<void> load() async {
    if (_isLoaded) return;
    _text = await File(id.path).readAsString();
    _isLoaded = true;
    notifyListeners();
  }

  String get text => _text;

  set text(String value) {
    if (value == _text) return;
    _text = value;
    notifyListeners();
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as FileTextContent;
    // _isLoaded = content._isLoaded;
    text = content.text;
  }

  @override
  Undoable takeSnapshot() {
    var content = FileTextContent(id);
    content._isLoaded = _isLoaded;
    content.text = text;
    return content;
  }
}

class OpenFileContentsManager extends NestedNotifier<FileContent> {
  OpenFileContentsManager() : super([]);

  FileContent? getContent(OpenFileData file, {bool autoCreate = true}) {
    for (var content in this) {
      if (content.id == file)
        return content;
    }
    if (autoCreate) {
      var content = FileContent.fromFile(file);
      add(content);
      return content;
    }
    return null;
  }

  bool isOpened(OpenFileData file) {
    for (var content in this) {
      if (content.id == file)
        return true;
    }
    return false;
  }
  
  @override
  Undoable takeSnapshot() {
    var snapshot = OpenFileContentsManager();
    snapshot.replaceWith(map((content) => content.takeSnapshot() as FileContent).toList());
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as OpenFileContentsManager;
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as FileContent);
  }
}

final fileContentsManager = OpenFileContentsManager();
