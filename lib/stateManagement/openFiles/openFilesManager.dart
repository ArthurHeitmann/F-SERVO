// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../utils/Disposable.dart';
import '../../utils/utils.dart';
import '../changesExporter.dart';
import '../events/statusInfo.dart';
import '../hasUuid.dart';
import '../listNotifier.dart';
import '../miscValues.dart';
import '../preferencesData.dart';
import '../undoable.dart';
import 'filesAreaManager.dart';
import 'openFileTypes.dart';

typedef OpenFileId = String;


class OpenFilesAreasManager with HasUuid, Undoable implements Disposable {
  final ListNotifier<FilesAreaManager> _areas = ValueListNotifier([]);
  IterableNotifier<FilesAreaManager> get areas => _areas;
  final ValueNotifier<FilesAreaManager?> _activeArea = ValueNotifier(null);
  ValueListenable<FilesAreaManager?> get activeArea => _activeArea;
  final FilesAreaManager hiddenArea;
  final ChangeNotifier subEvents = ChangeNotifier();
  final ChangeNotifier onSaveAll = ChangeNotifier();
  final Map<OpenFileId, OpenFileData> _filesMap = HashMap<OpenFileId, OpenFileData>();

  OpenFilesAreasManager([FilesAreaManager? hiddenArea])
    : hiddenArea = hiddenArea ?? FilesAreaManager() {
    areas.addListener(subEvents.notifyListeners);
  }

  bool isFileOpened(String path) {
    for (var area in areas) {
      for (var file in area.files) {
        if (file.path == path)
          return true;
      }
    }
    for (var file in hiddenArea.files) {
      if (file.path == path)
        return true;
    }
    return false;
  }

  OpenFileData? getFile(String path) {
    for (var area in areas) {
      for (var file in area.files) {
        if (file.path == path)
          return file;
      }
    }
    for (var file in hiddenArea.files) {
      if (file.path == path)
        return file;
    }
    return null;
  }

  OpenFileData? fromId(OpenFileId? id) {
    return _filesMap[id];
  }

  FilesAreaManager? getAreaOfFileId(OpenFileId searchFile, [bool includeHidden = true]) {
    for (var area in areas) {
      for (var file in area.files) {
        if (file.uuid == searchFile)
          return area;
      }
    }
    if (includeHidden) {
      for (var file in hiddenArea.files) {
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

  setActiveArea(FilesAreaManager? value) {
    assert(value == null || areas.contains(value));
    if (value == _activeArea.value)
      return;
    _activeArea.value = value;

    windowTitle.value = value?.currentFile.value?.displayName ?? "";
    
    undoHistoryManager.onUndoableEvent();
  }

  void ensureFileIsVisible(OpenFileData file) {
    var area = getAreaOfFile(file)!;
    if (area.currentFile.value != file)
      area.setCurrentFile(file);
  }

  OpenFileData openFile(
    String filePath, {
    FilesAreaManager? toArea,
    bool focusIfOpen = true,
    String? secondaryName,
    OptionalFileInfo? optionalInfo,
  }) {
    toArea ??= activeArea.value ?? areas[0];

    if (isFileOpened(filePath)) {
      var openFile = getFile(filePath)!;
      if (hiddenArea.files.contains(openFile)) {
        toArea.addFile(openFile);
        hiddenArea.removeFile(openFile);
      }
      if (focusIfOpen)
        getAreaOfFile(openFile)!.setCurrentFile(openFile);
      return openFile;
    }

    OpenFileData file = OpenFileData.from(
      path.basename(filePath),
      filePath,
      secondaryName: secondaryName,
      optionalInfo: optionalInfo,
    );
    toArea.addFile(file);
    toArea.setCurrentFile(file);
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
    hiddenArea.addFile(file);
    _filesMap[file.uuid] = file;
    return file;
  }

  void releaseHiddenFile(String filePath) {
    var file = hiddenArea.files.where((file) => file.path == filePath);
    if (file.isNotEmpty) {
      hiddenArea.removeFile(file.first);
      _filesMap.remove(file.first.uuid);
    }
  }

  void releaseFile(String filePath) {
    for (var area in areas.followedBy([hiddenArea])) {
      var files = area.files.where((file) => file.path == filePath);
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
    for (var area in areas) {
      prefs = area.files.find((file) => file is PreferencesData) as PreferencesData?;
      if (prefs != null)
        break;
    }
    if (prefs != null) {
      _activeArea.value = getAreaOfFile(prefs)!;
      activeArea.value!.setCurrentFile(prefs);
    }
    else {
      prefs = PreferencesData();
      await prefs.prefsFuture;
      activeArea.value!.addFile(prefs);
      activeArea.value!.setCurrentFile(prefs);
      _filesMap[prefs.uuid] = prefs;
    }
  }

  void addArea(FilesAreaManager child) {
    _areas.add(child);
    _activeArea.value ??= child;
    child.files.addListener(subEvents.notifyListeners);
  }

  void insertArea(int index, FilesAreaManager child) {
    _areas.insert(index, child);
    _activeArea.value ??= child;
    child.files.addListener(subEvents.notifyListeners);
  }

  void removeArea(FilesAreaManager child) {
    child.dispose();
    _areas.remove(child);
    if (child == _activeArea.value)
      _activeArea.value = areas.isNotEmpty ? areas[0] : null;
    child.files.removeListener(subEvents.notifyListeners);
  }

  FilesAreaManager removeAreaAt(int index) {
    var ret = _areas.removeAt(index);
    ret.dispose();
    if (ret == _activeArea.value)
      _activeArea.value = areas.isNotEmpty ? areas[0] : null;
    ret.files.removeListener(subEvents.notifyListeners);
    return ret;
  }

  void clearAreas() {
    _activeArea.value = null;
    for (var area in areas) {
      area.files.removeListener(subEvents.notifyListeners);
      area.dispose();
    }
    _areas.clear();
  }
  
  Future<void> saveAll() async {
    isLoadingStatus.pushIsLoading();
    try {
      await Future.wait([
        ...areas.map((area) => area.saveAll()),
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
    snapshot._areas.replaceWith(areas.map((area) => area.takeSnapshot() as FilesAreaManager).toList());
    snapshot._activeArea.value = _activeArea.value != null ? snapshot.areas[areas.indexOf(_activeArea.value!)] : null;
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as OpenFilesAreasManager;
    _areas.updateOrReplaceWith(entry.areas.toList(), (obj) => obj.takeSnapshot() as FilesAreaManager);
    hiddenArea.restoreWith(entry.hiddenArea);
    if (entry._activeArea.value != null)
      _activeArea.value = areas.where((area) => area.uuid == entry._activeArea.value!.uuid).first;
    else
      _activeArea.value = null;
    // regenerate files map
    _filesMap.clear();
    for (var area in areas) {
      for (var file in area.files) {
        _filesMap[file.uuid] = file;
      }
    }
  }

  @override
  void dispose() {
    areas.dispose();
    _activeArea.dispose();
    subEvents.dispose();
  }
}

final areasManager = OpenFilesAreasManager();
