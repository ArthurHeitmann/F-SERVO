import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../main.dart';
import '../utils/utils.dart';
import '../widgets/misc/confirmCancelDialog.dart';
import 'changesExporter.dart';
import 'miscValues.dart';
import 'nestedNotifier.dart';
import 'openFileTypes.dart';
import 'preferencesData.dart';
import 'events/statusInfo.dart';
import 'undoable.dart';

typedef OpenFileId = String;
class FilesAreaManager extends NestedNotifier<OpenFileData> implements Undoable {
  OpenFileData? _currentFile;

  FilesAreaManager() : super([]);

  OpenFileData? get currentFile => _currentFile;
  
  set currentFile(OpenFileData? value) {
    assert(value == null || contains(value));
    if (value == _currentFile) return;
    _currentFile = value;
    notifyListeners();
    
    if (this == areasManager.activeArea)
      windowTitle.value = currentFile?.displayName ?? "";
    
    undoHistoryManager.onUndoableEvent();
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

  Future<void> closeFile(OpenFileData file, { bool releaseHidden = false }) async {
    if (file.hasUnsavedChanges) {
      var answer = await confirmOrCancelDialog(
        getGlobalContext(),
        title: "Save changes?",
        body: "${file.name} has unsaved changes",
        yesText: "Save",
        noText: "Discard",
      );
      if (answer == true)
        await file.save();
      else if (answer == null)
        return;
    }
    if (file.keepOpenAsHidden && !releaseHidden)
      areasManager.hiddenArea.add(file);
    else if (releaseHidden) {
      areasManager.hiddenArea.remove(file);
      // TODO remove from areasManager
    }

    if (currentFile == file)
      switchToClosestFile();
    if (!releaseHidden || this != areasManager.hiddenArea)
      remove(file);

    if (length == 0 && areasManager.length > 1)
      areasManager.remove(this);
    
    undoHistoryManager.onUndoableEvent();
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
    rightArea.add(file);
    remove(file);
    rightArea.currentFile = file;
    
    if (length == 0) {
      areasManager.remove(this);
    }

    undoHistoryManager.onUndoableEvent();
  }

  void moveToLeftView(OpenFileData file) {
    if (currentFile == file)
      switchToClosestFile();
    
    int areaIndex = areasManager.indexOf(this);
    int leftAreaIndex = areaIndex - 1;
    FilesAreaManager leftArea;
    if (leftAreaIndex < 0 || leftAreaIndex >= areasManager.length) {
      leftArea = FilesAreaManager();
      areasManager.insert(clamp(leftAreaIndex, 0, areasManager.length), leftArea);
    }
    else {
      leftArea = areasManager[leftAreaIndex];
    }
    leftArea.add(file);
    remove(file);
    leftArea.currentFile = file;
    
    if (length == 0) {
      areasManager.remove(this);
    }
    
    undoHistoryManager.onUndoableEvent();
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
  
  Future<void> saveAll() async {
    try {
      await Future.wait(
        where((file) => file.hasUnsavedChanges)
        .map((file) => file.save()));
    } catch (e) {
      print("Error while saving all files");
      rethrow;
    }
  }

  @override
  void remove(OpenFileData child) {
    super.remove(child);
    if (areasManager.getAreaOfFile(child, true) == null)
      child.dispose();
  }

  @override
  void dispose() {
    for (var file in toList())
      remove(file);
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = FilesAreaManager();
    snapshot.overrideUuid(uuid);
    snapshot.replaceWith(map((entry) => entry.takeSnapshot() as OpenFileData).toList());
    snapshot._currentFile = _currentFile != null ? snapshot[indexOf(_currentFile!)] : null;
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as FilesAreaManager;
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as OpenFileData);
    if (entry._currentFile != null)
      currentFile = where((file) => file.uuid == entry._currentFile!.uuid).first;
    else
      currentFile = null;
  }
}

class OpenFilesAreasManager extends NestedNotifier<FilesAreaManager> {
  FilesAreaManager? _activeArea;
  final FilesAreaManager hiddenArea;
  final ChangeNotifier subEvents = ChangeNotifier();
  final ChangeNotifier onSaveAll = ChangeNotifier();
  final Map<OpenFileId, OpenFileData> _filesMap = HashMap<OpenFileId, OpenFileData>();

  OpenFilesAreasManager([FilesAreaManager? hiddenArea])
    : hiddenArea = hiddenArea ?? FilesAreaManager(),
    super([]) {
    addListener(subEvents.notifyListeners);
  }

  bool isFileOpened(String path) {
    for (var area in this) {
      for (var file in area) {
        if (file.path == path)
          return true;
      }
    }
    for (var file in hiddenArea) {
      if (file.path == path)
        return true;
    }
    return false;
  }

  OpenFileData? getFile(String path) {
    for (var area in this) {
      for (var file in area) {
        if (file.path == path)
          return file;
      }
    }
    for (var file in hiddenArea) {
      if (file.path == path)
        return file;
    }
    return null;
  }

  OpenFileData? fromId(OpenFileId? id) {
    return _filesMap[id];
  }
  FilesAreaManager? getAreaOfFileId(OpenFileId searchFile, [bool includeHidden = true]) {
    for (var area in this) {
      for (var file in area) {
        if (file.uuid == searchFile)
          return area;
      }
    }
    if (includeHidden) {
      for (var file in hiddenArea) {
        if (file.uuid == searchFile)
          return hiddenArea;
      }
    }
    return null;
  }

  FilesAreaManager? getAreaOfFile(OpenFileData searchFile, [bool includeHidden = true]) {
    return getAreaOfFileId(searchFile.uuid, includeHidden);
  }

  bool isFileIdOpen(OpenFileId id) {
    return _filesMap.containsKey(id);
  }

  FilesAreaManager? get activeArea => _activeArea;

  set activeArea(FilesAreaManager? value) {
    assert(value == null || contains(value));
    if (value == _activeArea)
      return;
    _activeArea = value;
    notifyListeners();

    windowTitle.value = value?.currentFile?.displayName ?? "";
    
    undoHistoryManager.onUndoableEvent();
  }

  void ensureFileIsVisible(OpenFileData file) {
    var area = getAreaOfFile(file)!;
    if (area.currentFile != file)
      area.currentFile = file;
  }

  OpenFileData openFile(
    String filePath, {
    FilesAreaManager? toArea,
    bool focusIfOpen = true,
    String? secondaryName,
    OptionalFileInfo? optionalInfo,
  }) {
    toArea ??= activeArea ?? this[0];

    if (isFileOpened(filePath)) {
      var openFile = getFile(filePath)!;
      if (hiddenArea.contains(openFile)) {
        toArea.add(openFile);
        hiddenArea.remove(openFile);
      }
      if (focusIfOpen)
        getAreaOfFile(openFile)!.currentFile = openFile;
      return openFile;
    }

    OpenFileData file = OpenFileData.from(
      path.basename(filePath),
      filePath,
      secondaryName: secondaryName,
      optionalInfo: optionalInfo,
    );
    toArea.add(file);
    toArea.currentFile = file;
    _filesMap[file.uuid] = file;

    undoHistoryManager.onUndoableEvent();

    return file;
  }

  OpenFileData openFileAsHidden(String filePath, { String? secondaryName, OptionalFileInfo? optionalInfo, }) {
    if (isFileOpened(filePath)) {
      return getFile(filePath)!;
    }
    OpenFileData file = OpenFileData.from(
      path.basename(filePath),
      filePath,
      secondaryName: secondaryName,
      optionalInfo: optionalInfo,
    );
    file.keepOpenAsHidden = true;
    hiddenArea.add(file);
    _filesMap[file.uuid] = file;
    return file;
  }

  void releaseHiddenFile(String filePath) {
    var file = hiddenArea.where((file) => file.path == filePath);
    if (file.isNotEmpty) {
      hiddenArea.remove(file.first);
      _filesMap.remove(file.first.uuid);
    }
  }

  void releaseFile(String filePath) {
    for (var area in [...this, hiddenArea]) {
      var files = area.where((file) => file.path == filePath);
      if (files.isNotEmpty) {
        var file = files.first;
        area.closeFile(file, releaseHidden: true);
        _filesMap.remove(file.uuid);
        break;
      }
    }
  }

  Future<void> openPreferences() async {
    PreferencesData? prefs;
    for (var area in this) {
      prefs = area.find((file) => file is PreferencesData) as PreferencesData?;
      if (prefs != null)
        break;
    }
    if (prefs != null) {
      activeArea = getAreaOfFile(prefs)!;
      activeArea!.currentFile = prefs;
    }
    else {
      prefs = PreferencesData();
      await prefs.prefsFuture;
      activeArea!.add(prefs);
      activeArea!.currentFile = prefs;
      _filesMap[prefs.uuid] = prefs;
    }
  }

  @override
  void add(FilesAreaManager child) {
    super.add(child);
    activeArea ??= child;
    child.addListener(subEvents.notifyListeners);
  }

  @override
  void remove(child) {
    child.removeListener(subEvents.notifyListeners);
    child.dispose();
    super.remove(child);
    if (child == _activeArea)
      _activeArea = isNotEmpty ? this[0] : null;
  }

  @override
  FilesAreaManager removeAt(int index) {
    this[index].removeListener(subEvents.notifyListeners);
    var ret = super.removeAt(index);
    ret.dispose();
    if (ret == _activeArea)
      _activeArea = isNotEmpty ? this[0] : null;
    return ret;
  }

  @override
  void clear() {
    _activeArea = null;
    for (var area in this) {
      area.removeListener(subEvents.notifyListeners);
      area.dispose();
    }
    super.clear();
  }
  
  Future<void> saveAll() async {
    isLoadingStatus.pushIsLoading();
    try {
      await Future.wait([
        ...map((area) => area.saveAll()),
        hiddenArea.saveAll()
      ]);
      onSaveAll.notifyListeners();
      await processChangedFiles();
    } catch (e) {
      showToast("Error saving files");
      rethrow;
    } finally {
      isLoadingStatus.popIsLoading();
      undoHistoryManager.onUndoableEvent();
    }
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = OpenFilesAreasManager(hiddenArea.takeSnapshot() as FilesAreaManager);
    snapshot.overrideUuid(uuid);
    snapshot.replaceWith(map((area) => area.takeSnapshot() as FilesAreaManager).toList());
    snapshot._activeArea = _activeArea != null ? snapshot[indexOf(_activeArea!)] : null;
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as OpenFilesAreasManager;
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as FilesAreaManager);
    hiddenArea.restoreWith(entry.hiddenArea);
    if (entry._activeArea != null)
      activeArea = where((area) => area.uuid == entry._activeArea!.uuid).first;
    else
      activeArea = null;
    // regenerate files map
    _filesMap.clear();
    for (var area in this) {
      for (var file in area) {
        _filesMap[file.uuid] = file;
      }
    }
  }
}

final areasManager = OpenFilesAreasManager();
