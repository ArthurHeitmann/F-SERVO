
import 'dart:io';
import 'package:path/path.dart';

import '../fileTypeUtils/dat/datRepacker.dart';
import '../fileTypeUtils/pak/pakRepacker.dart';
import '../fileTypeUtils/yax/xmlToYax.dart';
import '../utils.dart';
import 'openFileTypes.dart';
import 'preferencesData.dart';

List<XmlFileData> changedXmlFiles = [];
Set<String> changedPakFiles = {};
Set<String> changedDatFiles = {};

/// Convert changed files to YAX and repack PAK & DAT files
Future<void> processChangedFiles() async {
  var changedFiles = changedXmlFiles;
  changedXmlFiles = [];
  
  Set<String> paks = changedPakFiles;
  changedPakFiles = {};
  for (var file in changedFiles) {
    var dir = dirname(file.path);
    if (!dir.endsWith(".pak"))
      continue;
    paks.add(dir);
  }

  Set<String> dats = changedDatFiles;
  changedPakFiles = {};
  for (var pakDir in paks) {
    var datDir = dirname(dirname(pakDir));
    if (!datDir.endsWith(".dat"))
      continue;
    dats.add(datDir);
  }

  var prefs = PreferencesData();

  // convert all changed XMLs to YAX
  if (prefs.convertXmls?.value == true)
    await Future.wait(changedFiles.map((f) => xmlFileToYaxFile(f.path)));

  // convert potentially missing YAX files based on pak info
  // repack PAK
  if (prefs.exportPaks?.value == true) {
    await Future.wait(paks.map((pakDir) async {
      var pakFiles = await getPakInfoData(pakDir);
      for (var fileInfo in pakFiles) {
        String yaxName = fileInfo["name"];
        var yaxPath = join(pakDir, yaxName);
        if (!await File(yaxPath).exists()) {
          var xmlPath = "${yaxPath.substring(0, yaxPath.length - 4)}.xml";
          if (await File(xmlPath).exists()) {
            await xmlFileToYaxFile(xmlPath);
          }
        }
      }

      await repackPak(pakDir);
    }));
  }

  // repack DAT
  if (prefs.exportDats?.value == true && prefs.dataExportPath?.value != "") {
    await Future.wait(dats.map((datDir) {
      var datBaseName = basename(datDir);
      var exportPath = join(prefs.dataExportPath!.value, getDatFolder(datBaseName), datBaseName);
      return repackDat(datDir, exportPath);
    }));
  }
}