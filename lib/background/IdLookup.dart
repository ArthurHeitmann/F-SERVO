
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'IdsIndexer.dart';
import 'Initializable.dart';
import 'isolateCommincator.dart';

class IdLookup with Initializable {
  final IsolateCommunicator _worker;

  IdLookup() : _worker = IsolateCommunicator();

  Future<void> init() async {
    var prefs = await SharedPreferences.getInstance();
    var paths = prefs.getStringList("indexingPaths") ?? [];
    if (paths.isNotEmpty)
      await _worker.addIndexingPaths(paths);
    
    completeInitialization();
  }

  Future<IndexedIdData?> lookupId(int id) async {
    await awaitInitialized();
    return _worker.lookupId(id);
  }
}

final idLookup = IdLookup()
                ..init();
