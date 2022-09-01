import 'package:flutter/material.dart';

import '../stateManagement/nestedNotifier.dart';

class OpenFileData extends ChangeNotifier {
  String _name;
  String _path;
  bool _unsavedChanges = false;

  OpenFileData(this._name, this._path);

  String get name => _name;
  String get path => _path;
  bool get unsavedChanges => _unsavedChanges;

  set name(String value) {
    _name = value;
    notifyListeners();
  }
  set path(String value) {
    _path = value;
    notifyListeners();
  }
  set unsavedChanges(bool value) {
    _unsavedChanges = value;
    notifyListeners();
  }
}

class FilesAreaManager extends NestedNotifier<OpenFileData> {
  OpenFileData? _currentFile;

  FilesAreaManager() : super([]);

  OpenFileData? get currentFile => _currentFile;
  
  set currentFile(OpenFileData? value) {
    assert(value == null || contains(value));
    _currentFile = value;
    notifyListeners();
  }

  void closeFile(OpenFileData file) {
    remove(file);
    if (currentFile == file) {
      if (length > 0)
        currentFile = first;
      else
        currentFile = null;
    }
  }
}

class OpenFilesAreasManager extends NestedNotifier<FilesAreaManager> {
  OpenFilesAreasManager() : super([]);

}

final areasManager = OpenFilesAreasManager();
