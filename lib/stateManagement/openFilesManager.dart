import 'package:flutter/material.dart';

import '../filesView/FileType.dart';
import '../utils.dart';
import 'nestedNotifier.dart';
import 'openFileContents.dart';

class OpenFileData extends ChangeNotifier {
  final String uuid;
  String _name;
  String _path;
  bool _unsavedChanges = false;
  late final FileType type;

  OpenFileData(this._name, this._path)
    : type = FileType.text,
      uuid = uuidGen.v1();

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
    if (value == _currentFile) return;
    _currentFile = value;
    notifyListeners();
  }

  void switchToClosestFile() {
    if (length <= 1) {
      currentFile = null;
      return;
    }

    var index = indexOf(currentFile!);
    if (index + 1 == length)
      index--;
    else
      index++;
    currentFile = this[index];
  }

  void closeFile(OpenFileData file) {
    if (currentFile == file)
      switchToClosestFile();
    remove(file);
    if (fileContentsManager.isOpened(file))
      fileContentsManager.remove(fileContentsManager.getContent(file, autoCreate: false)!);

    if (length == 0 && areasManager.length > 1)
      areasManager.remove(this);
  }

  void closeAll() {
    var listCopy = List.from(this);
    for (var file in listCopy)
      closeFile(file);
  }

  void closeOthers(OpenFileData file) {
    var listCopy = List.from(this);
    for (var otherFile in listCopy)
      if (otherFile != file)
        closeFile(otherFile);
  }

  void closeToTheLeft(OpenFileData file) {
    var listCopy = List.from(this);
    int index = listCopy.indexOf(file);
    for (int i = 0; i < index; i++)
      closeFile(listCopy[i]);
  }

  void closeToTheRight(OpenFileData file) {
    var listCopy = List.from(this);
    int index = listCopy.indexOf(file);
    for (int i = index + 1; i < listCopy.length; i++)
      closeFile(listCopy[i]);
  }

  void moveToRightView(OpenFileData file) {
    if (currentFile == file)
      switchToClosestFile();
      
    int areaIndex = areasManager.indexOf(this);
    FilesAreaManager rightArea;
    if (areaIndex >= areasManager.length - 1) {
      rightArea = FilesAreaManager();
      areasManager.add(rightArea);
    }
    else {
      rightArea = areasManager[areaIndex + 1];
    }
    remove(file);
    rightArea.add(file);
    rightArea.currentFile = file;
    
    if (length == 0) {
      areasManager.remove(this);
    }
  }

  void moveToLeftView(OpenFileData file) {
    if (currentFile == file)
      switchToClosestFile();
    
    int areaIndex = areasManager.indexOf(this);
    int leftAreaIndex = areaIndex - 1;
    FilesAreaManager leftArea;
    if (leftAreaIndex < 0 || leftAreaIndex >= areasManager.length) {
      leftArea = FilesAreaManager();
      areasManager.insert(leftAreaIndex, leftArea);
    }
    else {
      leftArea = areasManager[leftAreaIndex];
    }
    remove(file);
    leftArea.add(file);
    leftArea.currentFile = file;
    
    if (length == 0) {
      areasManager.remove(this);
    }
  }

  void switchToNextFile() {
    if (length <= 1) return;
    int nextIndex = (indexOf(currentFile!) + 1) % length;
    currentFile = this[nextIndex];
  }

  void switchToPreviousFile() {
    if (length <= 1) return;
    int nextIndex = (indexOf(currentFile!) - 1) % length;
    if (nextIndex < 0)
      nextIndex += length;
    currentFile = this[nextIndex];
  }
}

class OpenFilesAreasManager extends NestedNotifier<FilesAreaManager> {
  OpenFilesAreasManager() : super([]);

  bool isFileOpened(String path) {
    for (var area in this) {
      for (var file in area) {
        if (file.path == path)
          return true;
      }
    }
    return false;
  }
}

final areasManager = OpenFilesAreasManager();
