
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import '../stateManagement/events/miscEvents.dart';
import '../stateManagement/preferencesData.dart';

class WemFilesLookup {
  final Map<int, String> lookup = {};
  final Map<String, Map<int, String>> _tmpLookupCache = {};
  Completer<void>? loadingCompleter;

  WemFilesLookup() {
    var prefs = PreferencesData();
    prefs.waiExtractDir?.addListener(updateIndex);
    onWaiFilesExtractedStream.listen((_) => updateIndex());
  }

  Future<void> updateIndex() async {
    loadingCompleter = Completer();
    lookup.clear();
    var prefs = PreferencesData();
    var waiExtractDir = prefs.waiExtractDir?.value;
    if (waiExtractDir == null || waiExtractDir.isEmpty) {
      loadingCompleter!.complete();
      return;
    }
    String dataPath = prefs.dataExportPath?.value ?? "";
    if (dataPath.isNotEmpty) {
      dataPath = join(dataPath, "sound", "stream");
    }

    try {
      await _indexDir(waiExtractDir);
      if (await Directory(dataPath).exists()) {
        await _indexDir(dataPath, recursive: false);
      }
    } catch (e) {
      print("Error indexing WAI files:");
      print(e);
    }

    loadingCompleter!.complete();
    print("Found ${lookup.length} WEM files");
  }

  Future<String?> lookupWithAdditionalDir(int id, String dir) async {
    if (loadingCompleter != null)
      await loadingCompleter!.future;
    if (lookup.containsKey(id))
      return lookup[id];
    if (_tmpLookupCache.containsKey(dir)) {
      var dirLookup = _tmpLookupCache[dir]!;
      if (dirLookup.containsKey(id))
        return dirLookup[id];
    }
    var dirLookup = await _getDirLookup(dir);
    _tmpLookupCache[dir] = dirLookup;
    if (dirLookup.containsKey(id))
      return dirLookup[id];
    return null;
  }

  Future<void> _indexDir(String dir, { bool recursive = true }) async {
    var lookup = await _getDirLookup(dir, recursive: recursive);
    this.lookup.addAll(lookup);
  }

  Future<Map<int, String>> _getDirLookup(String dir, { bool recursive = true }) async {
    var lookup = <int, String>{};
    var fileList = await Directory(dir)
      .list(recursive: recursive)
      .where((e) => e is File && RegExp(r"\d+\.wem$").hasMatch(e.path))
      .toList();

    for (var file in fileList) {
      var idStr = RegExp(r"(\d+)\.wem$").firstMatch(file.path)!.group(1)!;
      var id = int.parse(idStr);
      lookup[id] = file.path;
    }
    return lookup;
  }
}
final wemFilesLookup = WemFilesLookup();
