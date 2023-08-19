
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import '../stateManagement/events/miscEvents.dart';
import '../stateManagement/preferencesData.dart';

class WemFilesLookup {
  final Map<int, String> lookup = {};
  Completer<void>? loadingCompleter;

  WemFilesLookup() {
    var prefs = PreferencesData();
    prefs.waiExtractDir?.addListener(updateIndex);
    prefs.wemExtractDir?.addListener(updateIndex);
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

    try {
      await _indexDir(waiExtractDir);
      if (prefs.wemExtractDir != null && prefs.wemExtractDir!.value.isNotEmpty)
        await _indexDir(prefs.wemExtractDir!.value);
    } catch (e) {
      print("Error indexing WAI files:");
      print(e);
    }

    loadingCompleter!.complete();
    print("Found ${lookup.length} WEM files");
  }

  Future<void> _indexDir(String dir) async {
    var fileList = await Directory(dir)
      .list(recursive: true)
      .where((e) => e is File && RegExp(r"\d+\.wem$").hasMatch(e.path))
      // .where((e) => dirname(e.path).endsWith(".wsp"))
      .toList();
    
    for (var file in fileList) {
      var idStr = RegExp(r"(\d+)\.wem$").firstMatch(file.path)!.group(1)!;
      var id = int.parse(idStr);
      lookup[id] = file.path;
    }
  }
}
final wemFilesLookup = WemFilesLookup();
