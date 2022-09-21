
import 'IdsIndexer.dart';

class IndexingService {
  final List<IdsIndexer> _indexers = [];

  Future<void> addPaths(List<String> paths) async {
    paths = paths.where((path) => !_indexers.any((indexer) => indexer.path == path)).toList();
    List<Future<void>> futures = [];
    for (var path in paths) {
      var indexer = IdsIndexer();
      futures.add(indexer.indexPath(path));
      _indexers.add(indexer);
    }

    await Future.wait(futures);
  }

  Future<void> _ensureAllInitialized() {
    List<Future<void>> futures = [];
    for (var indexer in _indexers)
      futures.add(indexer.awaitInitialized());
    return Future.wait(futures);
  }

  Future<IndexedIdData?> lookupId(int id) async {
    await _ensureAllInitialized();
    for (var indexer in _indexers) {
      var data = indexer.indexedIds[id];
      if (data != null)
        return data;
    }
    return null;
  }
}


