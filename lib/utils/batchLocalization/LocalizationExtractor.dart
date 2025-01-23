
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/dat/datExtractor.dart';
import '../../fileTypeUtils/mcd/mcdIO.dart';
import '../../fileTypeUtils/pak/pakExtractor.dart';
import '../../fileTypeUtils/ruby/pythonRuby.dart';
import '../../fileTypeUtils/smd/smdReader.dart';
import '../../fileTypeUtils/tmd/tmdReader.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../utils.dart';
import 'BatchLocalizationData.dart';
import 'batchLocalizationUtils.dart';

Future<void> extractLocalizationFiles({
  required String workDir,
  required List<String> searchPaths,
  required String savePath,
  required BatchLocalizationLanguage language,
  required bool reextractDats,
  required bool extractMcd,
  required bool extractTmd,
  required bool extractSmd,
  required bool extractRb,
  required bool extractHap,
  required BatchLocExtractionProgress progress,
}) async {
  var datDttFiles = (await Future.wait(
    searchPaths.map((searchPath) => Directory(searchPath)
      .list(recursive: true)
      .where((file) => file.path.endsWith(".dat") ||  file.path.endsWith(".dtt"))
      .toList())
  ))
    .expand((files) => files)
    .whereType<File>()
    .toList();
  var datFiles = datDttFiles.where((file) => file.path.endsWith(".dat")).toList();
  progress.totalFiles = datFiles.length;
  
  var datDir = join(workDir, "dat");
  await Directory(datDir).create(recursive: true);
  List<BatchLocalizationFileData> fileLoc = [];
  for (var datFile in datFiles) {
    progress.processedFiles++;
    progress.currentFile = basename(datFile.path);
    progress.update();
    try {
      var parentDir = basename(dirname(datFile.path));
      var datLang = _getLangFromDat(datFile.path);
      if (parentDir == "ui") {
        if(!extractMcd)
          continue;
        if (datLang != language)
          continue;
        if (await datFile.length() == 0)
          continue;
        var mcdBaseName = _nameWithoutLang(datFile.path);
        if (mcdBaseName.startsWith("ui_")) {
          mcdBaseName = mcdBaseName.substring(3);
          mcdBaseName = "mess$mcdBaseName";
        }
        var mcdPath = join(await _getExtractedDir(datFile.path, datDir, reextractDats), "$mcdBaseName.mcd");
        var mcdData = await _getMcdData(mcdPath);
        if (mcdData != null) {
          fileLoc.add(mcdData);
          var dttSrcPath = datFile.path.replaceFirst(".dat", ".dtt");
          var dttDestPath = join(datDir, basename(dttSrcPath));
          if (!await File(dttDestPath).exists() || reextractDats) {
            await File(dttSrcPath).copy(dttDestPath);
            await extractDatFiles(dttDestPath);
          }
        }
      }
      else if (parentDir == "txtmess") {
        if(!extractTmd)
          continue;
        if (datLang != language)
          continue;
        var tmdPath = join(await _getExtractedDir(datFile.path, datDir, reextractDats), "${_nameWithoutLang(datFile.path)}.tmd");
        var tmdData = await _getTmdSmdData(tmdPath);
        if (tmdData != null) {
          fileLoc.add(tmdData);
        }
      }
      else if (parentDir == "subtitle") {
        if(!extractSmd)
          continue;
        if (datLang != language)
          continue;
        var smdPath = join(await _getExtractedDir(datFile.path, datDir, reextractDats), "${_nameWithoutLang(datFile.path)}.smd");
        var smdData = await _getTmdSmdData(smdPath);
        if (smdData != null) {
          fileLoc.add(smdData);
        }
      }
      else if (datFile.path.endsWith("corehap.dat")) {
        if (!extractHap)
          continue;
        var hapDatDir = await _getExtractedDir(datFile.path, datDir, reextractDats);
        var hapData = await _getCoreHapData(hapDatDir, language, reextractDats);
        if (hapData != null) {
          fileLoc.add(hapData);
        }
      }
      else if (
        parentDir == "core" ||
        parentDir == "quest" ||
        parentDir.startsWith("ph") ||
        parentDir.startsWith("st") ||
        parentDir.startsWith("wd")
      ) {
        if(!extractRb)
          continue;
        var datContents = await peekDatFileNames(datFile.path);
        var hasRbFiles = datContents.any((file) => file.endsWith("_scp.bin"));
        if (!hasRbFiles)
          continue;
        var rbDatDir = await _getExtractedDir(datFile.path, datDir, reextractDats);
        var rbData = await _getRbData(rbDatDir, language, reextractDats);
        fileLoc.addAll(rbData);
      }
    } catch (e, stack) {
      messageLog.add("Error while processing $datFile: $e\n$stack");
    }
  }
  progress.currentFile = null;

  var locData = BatchLocalizationData(fileLoc, language);
  var useJson = savePath.endsWith(".json");
  String fileString;
  if (useJson) {
    fileString = JsonEncoder.withIndent("  ").convert(locData.toJson());
  }
  else {
    var writer = StringBuffer();
    locData.writeString(writer);
    fileString = writer.toString();
  }
  await File(savePath).writeAsString(fileString);

  showToast("All text saved to $savePath");
}

Future<String> _getExtractedDir(String datPath, String datWorkDir, bool reextractDats) async {
  var datNewPath = join(datWorkDir, basename(datPath));
  if (!await File(datNewPath).exists() || reextractDats)
    await File(datPath).copy(datNewPath);
  var extractedDir = join(dirname(datNewPath), datSubExtractDir, basename(datNewPath));
  if (await Directory(extractedDir).exists()) {
    if (reextractDats) {
      await Directory(extractedDir).delete(recursive: true);
      await extractDatFiles(datNewPath);
    }
  } else {
    await extractDatFiles(datNewPath);
  }
  return extractedDir;
}

String _nameWithoutLang(String datPath) {
  var name = basenameWithoutExtension(datPath);
  var endPos = name.lastIndexOf("_");
  if (endPos == -1)
    return name;
  return name.substring(0, endPos);
}

Future<BatchLocalizationFileData?> _getTmdSmdData(String tmdSmdPath) async {
  if (!await File(tmdSmdPath).exists())
    return null;
  List<BatchLocalizationEntryData> entries;
  if (tmdSmdPath.endsWith(".tmd")) {
    entries = (await readTmdFile(tmdSmdPath))
      .map((entry) => BatchLocalizationEntryData(entry.id, entry.text))
      .toList();
  } else {
    entries = (await readSmdFile(tmdSmdPath))
      .map((entry) => BatchLocalizationEntryData(entry.id, entry.text))
      .toList();
  }
  if (entries.isEmpty)
    return null;
  var datPath = basename(dirname(tmdSmdPath));
  return BatchLocalizationFileData(
    basename(datPath),
    basename(tmdSmdPath),
    entries,
  );
}

Future<List<BatchLocalizationFileData>> _getRbData(String datDir, BatchLocalizationLanguage langFilter, bool reextractDats) async {
  var binFiles = await Directory(datDir)
    .list()
    .where((file) => file.path.endsWith("_scp.bin"))
    .toList();
  List<BatchLocalizationFileData> files = [];
  await Future.wait(binFiles.map((binFile) async {
    var rbPath = "${binFile.path}.rb";
    if (!await File(rbPath).exists() || reextractDats)
      await binFileToRuby(binFile.path);
    
    List<BatchLocalizationEntryData> entries = [];
    var rbText = await File(rbPath).readAsString();
    var arrayRegex = RegExp(r'	(\w+) = \[\n(?:		".*",?\n){3,}	\]');
    var matches = arrayRegex.allMatches(rbText);
    for (var match in matches) {
      var key = match.group(1);
      var strRegex = RegExp(r'		"(.*)",?\n');
      var strings = strRegex.allMatches(match.group(0)!);
      for (var (i, string) in strings.indexed) {
        if (i >= batchLocRbOrder.length)
          break;
        var lang = batchLocRbOrder[i];
        if (langFilter != lang)
          continue;
        entries.add(BatchLocalizationEntryData(key!, string.group(1)!));
      }
    }
    if (entries.isNotEmpty) {
      var datPath = basename(dirname(binFile.path));
      files.add(BatchLocalizationFileData(
        basename(datPath),
        basename(rbPath),
        entries,
      ));
    }
  }));
  return files;
}

Future<BatchLocalizationFileData?> _getMcdData(String mcdPath) async {
  if (!await File(mcdPath).exists())
    return null;
  var mcd = await McdFile.fromFile(mcdPath);
  List<BatchLocalizationEntryData> entries = [];
  for (var event in mcd.events) {
    var key = event.name;
    var paragraph = event.message.paragraphs.first;
    List<String> lines = [] ;
    for (var line in paragraph.lines) {
      var text = line.toString();
      lines.add(text);
    }
    var text = lines.join("\n");
    entries.add(BatchLocalizationEntryData(key, text));
  }
  if (entries.isEmpty)
    return null;
  var datPath = basename(dirname(mcdPath));
  return BatchLocalizationFileData(
    basename(datPath),
    basename(mcdPath),
    entries,
  );
}

Future<BatchLocalizationFileData?> _getCoreHapData(String datDir, BatchLocalizationLanguage langFilter, bool reextractDats) async {
  var corehapPath = join(datDir, "core_hap.pak");
  var corehapExtractedPath = join(datDir, "pakExtracted", "core_hap.pak");
  if (!await File(corehapExtractedPath).exists() || reextractDats)
    await extractPakFiles(corehapPath, yaxToXml: true);
  var charNameXmlPath = join(corehapExtractedPath, "25.xml");
  if (!await File(charNameXmlPath).exists())
    return null;
  var charNameXmlStr = await File(charNameXmlPath).readAsString();
  var charNameXml = XmlDocument.parse(charNameXmlStr).rootElement;
  var name = charNameXml.getElement("name")?.innerText;
  if (name != "CharName")
    return null;
  var hexStr = charNameXml
    .getElement("text")
    ?.findElements("value")
    .map((element) => element.innerText)
    .join("");
  if (hexStr == null)
    return null;
  var hexData = hex.decode(hexStr);
  var charNamesStr = utf8.decode(hexData, allowMalformed: true);
  var lines = charNamesStr.split("\n");
  lines = lines.sublist(1, lines.length - 1);
  List<BatchLocalizationEntryData> entries = [];
  String currentKey = "";
  for (var line in lines) {
    if (line.startsWith("  ")) {
      line = line.substring(2);
      var spaceIndex = line.indexOf(" ");
      var key = line.substring(0, spaceIndex);
      var val = line.substring(spaceIndex + 1);
      var lang = charNameKeysToBatchLocLang[key];
      if (langFilter != lang)
        continue;
      entries.add(BatchLocalizationEntryData(currentKey, val));
    }
    else {
      currentKey = line.substring(1);
    }
  }
  if (entries.isEmpty)
    return null;
  var datPath = basename(dirname(corehapPath));
  return BatchLocalizationFileData(
    basename(datPath),
    basename(corehapPath),
    entries,
  );
}

const _extToLang = {
  "us": BatchLocalizationLanguage.us,
  "fr": BatchLocalizationLanguage.fr,
  "de": BatchLocalizationLanguage.de,
  "it": BatchLocalizationLanguage.it,
  "jp": BatchLocalizationLanguage.jp,
  "es": BatchLocalizationLanguage.es,
};
BatchLocalizationLanguage? _getLangFromDat(String datPath) {
  var name = basenameWithoutExtension(datPath);
  var parts = name.split("_");
  if (parts.length == 1)
    return BatchLocalizationLanguage.jp;
  return _extToLang[parts.last];
}

class BatchLocExtractionProgress extends ChangeNotifier {
  bool isRunning = false;
  String? error;
  int totalFiles = 0;
  int processedFiles = 0;
  String? currentFile;
  
  void reset() {
    isRunning = false;
    error = null;
    totalFiles = 0;
    processedFiles = 0;
    currentFile = null;
    notifyListeners();
  }

  void update() {
    notifyListeners();
  }
}
