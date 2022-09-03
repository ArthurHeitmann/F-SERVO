
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/filesView/FileType.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';
import 'package:nier_scripts_editor/stateManagement/openFilesManager.dart';

class FileContent extends ChangeNotifier {
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
    _text = value;
    notifyListeners();
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
}

final fileContentsManager = OpenFileContentsManager();
