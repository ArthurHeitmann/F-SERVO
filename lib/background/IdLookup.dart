
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../stateManagement/miscValues.dart';
import '../stateManagement/openFileTypes.dart';
import '../stateManagement/openFilesManager.dart';
import '../utils/utils.dart';
import 'IdsIndexer.dart';
import 'Initializable.dart';
import 'isolateCommunicator.dart';

class IdLookup with Initializable {
  /// (3. level) one time (or occasional) indexing of ids from paths in preferences
  final IsolateCommunicator _heavyWorker = IsolateCommunicator();
  /// (2. level) ids of changed files
  final IsolateCommunicator _coldStorage = IsolateCommunicator();
  /// (1. level) ids of currently changed files
  final List<IdsIndexer> _changedFiles = [];
  final List<OpenFileData> _openFiles = [];
  final List<void Function()> _filesChangesListeners = [];

  IdLookup();

  Future<void> init() async {
    var prefs = await SharedPreferences.getInstance();
    var paths = prefs.getStringList("indexingPaths") ?? [];
    if (paths.isNotEmpty)
      await _heavyWorker.addIndexingPaths(paths);
    
    areasManager.subEvents.addListener(_onFilesAddedOrRemoved);
    areasManager.onSaveAll.addListener(_onFilesSaved);

    completeInitialization();
  }

  Future<void> addIndexingPaths(List<String> paths) async {
    await _heavyWorker.addIndexingPaths(paths);
  }
  
  Future<void> removeIndexingPaths(List<String> paths) async {
    await _heavyWorker.removeIndexingPaths(paths);
  }

  Future<void> clearIndexingPaths() async {
    await _heavyWorker.clearIndexingPaths();
  }

  Future<List<IndexedIdData>> lookupId(int id) async {
    await awaitInitialized();
    var result = await _lookupIdLevel1(id);
    if (result.isEmpty) {
      result = await _lookupIdLevel2(id);
      if (result.isEmpty)
        result = await _lookupIdLevel3(id);
    }
    
    // remove duplicates
    return result.toSet().toList();
  }

  Future<List<IndexedIdData>> _lookupIdLevel3(int id) async {
    return _heavyWorker.lookupId(id);
  }

  Future<List<IndexedIdData>> _lookupIdLevel2(int id) async {
    return _coldStorage.lookupId(id);
  }

  Future<List<IndexedIdData>> _lookupIdLevel1(int id) async {
    for (var file in _changedFiles) {
      var data = file.indexedIds[id];
      if (data != null)
        return data;
    }
    return [];
  }

  void _onFilesAddedOrRemoved() {
    // search for new files
    for (var area in areasManager) {
      for (var file in area) {
        if (!file.path.endsWith(".xml"))
          continue;
        if (_openFiles.contains(file))
          continue;
        var debouncedListener = debounce(() => _onFileChanged(file), 1000);
        listener() {
          if (disableFileChanges)
            return;
          debouncedListener();
        }
        _openFiles.add(file);
        _filesChangesListeners.add(listener);
        file.contentNotifier.addListener(listener);
      }
    }
    // search for removed files
    for (var i = _openFiles.length - 1; i >= 0; i--) {
      if (areasManager.getAreaOfFile(_openFiles[i]) != null)
        continue;
      _openFiles[i].contentNotifier.removeListener(_filesChangesListeners[i]);
      _openFiles.removeAt(i);
      _filesChangesListeners.removeAt(i);
    }
  }

  void _onFileChanged(OpenFileData file) async {
    if (file is! XmlFileData || file.root == null)
      return;
    await _coldStorage.removeIndexingPaths([file.path]);
    
    var indexers = _changedFiles
                    .where((indexer) => indexer.path == file.path)
                    .toList();
    if (indexers.isNotEmpty) {
      indexers.first.clear();
      indexers.first.indexXml(file.root!.toXml(), file.path);
    }
    else {
      var indexer = IdsIndexer();
      _changedFiles.add(indexer);
      indexer.clear();
      indexer.indexXml(file.root!.toXml(), file.path);
    }
  }

  void _onFilesSaved() {
    var changedPaths = _changedFiles
      .where((indexer) => indexer.path != null)
      .map((indexer) => indexer.path!)
      .toList();
      
    _coldStorage.addIndexingPaths(changedPaths);
    _changedFiles.clear();
  }
}

final idLookup = IdLookup();
