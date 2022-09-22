
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../stateManagement/openFileTypes.dart';
import '../stateManagement/openFilesManager.dart';
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
    paths.add(r"D:\delete\mods\na\blender\extracted\");
    if (paths.isNotEmpty)
      await _heavyWorker.addIndexingPaths(paths);
    
    areasManager.subEvents.addListener(_onFilesAddedOrRemoved);
    areasManager.onSaveAll.addListener(_onFilesSaved);

    completeInitialization();
  }

  Future<IndexedIdData?> lookupId(int id) async {
    await awaitInitialized();
    return 
      await _lookupIdLevel1(id) ??
      await _lookupIdLevel2(id) ??
      await _lookupIdLevel3(id);
  }

  Future<IndexedIdData?> _lookupIdLevel3(int id) async {
    return _heavyWorker.lookupId(id);
  }

  Future<IndexedIdData?> _lookupIdLevel2(int id) async {
    return _coldStorage.lookupId(id);
  }

  Future<IndexedIdData?> _lookupIdLevel1(int id) async {
    for (var file in _changedFiles) {
      var data = file.indexedIds[id];
      if (data != null)
        return data;
    }
    return null;
  }

  void _onFilesAddedOrRemoved() {
    // search for new files
    for (var area in areasManager) {
      for (var file in area) {
        if (!file.path.endsWith(".xml"))
          continue;
        if (_openFiles.contains(file))
          continue;
        listener() => _onFileChanged(file);
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

final idLookup = IdLookup()
                ..init();
