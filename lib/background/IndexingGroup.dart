
import 'IdsIndexer.dart';

class IndexingGroup {
  final List<IdsIndexer> _indexers = [];
  void Function(bool)? onLoadingStateChange;

  Future<void> addPaths(List<String> paths) async {
    List<Future<void>> futures = [];
    
    paths = paths.where((path) => !_indexers.any((indexer) => indexer.path == path)).toList();
    removePaths(paths);
    for (var path in paths) {
      var indexer = IdsIndexer();
      indexer.onLoadingStateChange = (isLoading) => onLoadingStateChange?.call(isLoading);
      futures.add(indexer.indexPath(path));
      _indexers.add(indexer);
    }

    await Future.wait(futures);

    print("Indexed ${paths.length} paths");
  }

  void removePaths(List<String> paths) {
    var indexers = _indexers.where((indexer) => paths.contains(indexer.path));
    for (var indexer in indexers.toList()) {
      indexer.stop();
      _indexers.remove(indexer);
    }
    print("Stopped indexing ${paths.length} paths");
  }

  void clearPaths() {
    for (var indexer in _indexers) {
      indexer.stop();
    }
    _indexers.clear();

    print("Stopped indexing all paths");
  }

  Future<void> _ensureAllInitialized() {
    List<Future<void>> futures = [];
    for (var indexer in _indexers)
      futures.add(indexer.awaitInitialized());
    return Future.wait(futures);
  }

  Future<List<IndexedIdData>> lookupId(int id) async {
    await _ensureAllInitialized();
    for (var indexer in _indexers) {
      var data = indexer.indexedIds[id];
      if (data != null)
        return data;
    }
    return [];
  }

  Future<IndexedCharNameData?> lookupCharName(String charNameKey) async {
    await _ensureAllInitialized();
    for (var indexer in _indexers) {
      var data = indexer.indexedCharNames[charNameKey];
      if (data != null)
        return data;
    }
    return null;
  }

  Future<List<IndexedCharNameData>> getAllCharNames() async {
    await _ensureAllInitialized();
    List<IndexedCharNameData> charNames = [];
    for (var indexer in _indexers) {
      charNames.addAll(indexer.indexedCharNames.values);
    }
    return charNames;
  }

  Future<IndexedSceneStateData?> lookupSceneState(String sceneStateKey) async {
    await _ensureAllInitialized();
    for (var indexer in _indexers) {
      var data = indexer.indexedSceneStates[sceneStateKey];
      if (data != null)
        return data;
    }
    return null;
  }

  Future<List<IndexedSceneStateData>> getAllSceneStates() async {
    await _ensureAllInitialized();
    List<IndexedSceneStateData> sceneStates = [];
    for (var indexer in _indexers) {
      sceneStates.addAll(indexer.indexedSceneStates.values);
    }
    return sceneStates;
  }
}
