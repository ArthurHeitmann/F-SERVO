
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/dat/datRepacker.dart';
import '../../fileTypeUtils/pak/pakRepacker.dart';
import '../../fileTypeUtils/ruby/pythonRuby.dart';
import '../../fileTypeUtils/smd/smdReader.dart';
import '../../fileTypeUtils/smd/smdWriter.dart';
import '../../fileTypeUtils/tmd/tmdReader.dart';
import '../../fileTypeUtils/tmd/tmdWriter.dart';
import '../../fileTypeUtils/xml/xmlExtension.dart';
import '../../fileTypeUtils/yax/xmlToYax.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/openFiles/types/McdFileData.dart';
import '../utils.dart';
import 'BatchLocalizationData.dart';
import 'batchLocalizationUtils.dart';


Future<void> exportBatchLocalization({
  required String workingDirectory,
  required String localizationFile,
  required String exportFolder,
  required BatchLocExportProgress progress,
}) async {
  BatchLocalizationData data;
  if (localizationFile.endsWith(".json")) {
    var json = await File(localizationFile).readAsString();
    data = BatchLocalizationData.fromJson(jsonDecode(json));
  } else {
    var fileStr = await File(localizationFile).readAsString();
    fileStr = fileStr.replaceAll("\r\n", "\n");
    var reader = StringReader(fileStr);
    data = BatchLocalizationData.read(reader);
  }

  progress.step = 1;
  progress.totalSteps = 2;
  progress.stepName = "Check and save changes";
  progress.totalFiles = data.files.length;
  progress.file = 0;
  progress.notify();
  int errors = 0;
  
  var datDir = join(workingDirectory, "dat", datSubExtractDir);
  List<String> datFilesToExport = [];
  for (var locFile in data.files) {
    progress.file++;
    progress.currentFile = locFile.fileName;
    progress.notify();
    try {
      if (locFile.fileName.endsWith(".mcd")) {
        await _processMcd(locFile, datDir, datFilesToExport);
      }
      else if (locFile.fileName.endsWith(".tmd")) {
        await _processTmd(locFile, datDir, datFilesToExport);
      }
      else if (locFile.fileName.endsWith(".smd")) {
        await _processSmd(locFile, datDir, datFilesToExport);
      }
      else if (locFile.fileName.endsWith(".rb")) {
        await _processRb(locFile, datDir, datFilesToExport, data.language);
      }
      else if (locFile.fileName.endsWith(".pak")) {
        await _processHap(locFile, datDir, datFilesToExport, data.language);
      }
      else {
        messageLog.add("Unsupported file type: ${locFile.fileName}");
        errors++;
      }
    } on Exception catch (e, st) {
      messageLog.add("Error processing ${locFile.fileName}: $e\n$st");
      errors++;
    }
  }
  datFilesToExport = deduplicate(datFilesToExport);

  progress.step = 2;
  progress.stepName = "Repack DAT files";
  progress.totalFiles = datFilesToExport.length;
  progress.file = 0;
  progress.currentFile = null;

  for (var exportDatName in datFilesToExport) {
    progress.file++;
    progress.currentFile = exportDatName;
    progress.notify();
    var datFolder = join(datDir, exportDatName);
    var exportSubDir = getDatFolder(exportDatName);
    var exportPath = join(exportFolder, exportSubDir, exportDatName);
    await repackDat(datFolder, exportPath);
  }

  if (errors == 0)
    showToast("Export completed successfully");
  else
    showToast("Export completed with ${pluralStr(errors, "error")}");
}

Future<void> _processTmd(BatchLocalizationFileData locFile, String datDir, List<String> datFilesToExport) async {
  var tmdPath = join(datDir, locFile.datName, locFile.fileName);
  var srcTmdEntries = await readTmdFile(tmdPath);
  var locMap = locFile.asMapOfLists();
  Map<String, int> visitedCounts = {};
  var hasChanges = false;
  var newEntries = srcTmdEntries.map((e) {
    var loc = _lookupLocWithDuplicates(locMap, e.id, visitedCounts);
    if (loc == null)
      return e;
    hasChanges |= e.text != loc;
    return TmdEntry.fromStrings(e.id, loc);
  }).toList();

  if (hasChanges) {
    await saveTmd(newEntries, tmdPath);
    datFilesToExport.add(locFile.datName);
  }
}

Future<void> _processSmd(BatchLocalizationFileData locFile, String datDir, List<String> datFilesToExport) async {
  var smdPath = join(datDir, locFile.datName, locFile.fileName);
  var srcSmdEntries = await readSmdFile(smdPath);
  var locMap = locFile.asMap();
  var hasChanges = false;
  var newEntries = srcSmdEntries.indexed.map((ie) {
    var (i, e) = ie;
    var loc = locMap[e.id];
    if (loc == null)
      return e;
    if (loc.contains("\n") && !loc.contains("\r\n"))
      loc = loc.replaceAll("\n", "\r\n");
    hasChanges |= e.text != loc;
    return SmdEntry(e.id, i * 10, loc);
  }).toList();

  if (hasChanges) {
    await saveSmd(newEntries, smdPath);
    datFilesToExport.add(locFile.datName);
  }
}

Future<void> _processRb(BatchLocalizationFileData locFile, String datDir, List<String> datFilesToExport, BatchLocalizationLanguage lang) async {
  var rbPath = join(datDir, locFile.datName, locFile.fileName);
  var rbStr = await File(rbPath).readAsString();
  var hasChanges = false;
  var langIndex = batchLocRbOrder.indexOf(lang);
  if (langIndex == -1) {
    throw Exception("Language not found in order: $lang");
  }
  var locMap = locFile.asMap();
  var regex = RegExp(r'	(\w+) = \[\n(?:		"[^\n]+",\n){' + langIndex.toString() + r'}		"[^\n]+(?=")');
  var newRbStr = rbStr.replaceAllMapped(regex, (match) {
    var key = match.group(1)!;
    var fullMatch = match.group(0)!;
    if (!locMap.containsKey(key))
      return fullMatch;
    var replaceStart = fullMatch.lastIndexOf('\n\t\t"') + 4;
    return fullMatch.replaceRange(replaceStart, fullMatch.length, locMap[key]!);
  });
  hasChanges = newRbStr != rbStr;

  if (hasChanges) {
    await File(rbPath).writeAsString(newRbStr);
    await rubyFileToBin(rbPath);
    datFilesToExport.add(locFile.datName);
  }
}

Future<void> _processHap(BatchLocalizationFileData locFile, String datDir, List<String> datFilesToExport, BatchLocalizationLanguage langFilter) async {
  var pakPath = join(datDir, locFile.datName, "pakExtracted", "core_hap.pak");
  var xml = join(pakPath, "25.xml");
  var charNameXmlStr = await File(xml).readAsString();
  var charNameXml = XmlDocument.parse(charNameXmlStr).rootElement;
  var name = charNameXml.getElement("name")?.innerText;
  if (name != "CharName") {
    return;
  }
  var textParent = charNameXml
    .getElement("text");
  var hexStr = textParent
    ?.findElements("value")
    .map((element) => element.innerText)
    .join("");
  if (hexStr == null) {
    return;
  }
  var hexData = hex.decode(hexStr);
  var newLineCode = "\n".codeUnitAt(0);
  var firstLineEnd = hexData.indexOf(newLineCode) + 1;
  var firstLine = hexData.sublist(0, firstLineEnd);
  hexData = hexData.sublist(firstLineEnd);
  var charNamesStr = utf8.decode(hexData, allowMalformed: true);
  var lines = charNamesStr.split("\n");
  var locMap = locFile.asMapOfLists();
  Map<String, int> visitedCounts = {};
  var hasChanges = false;
  var newCharNames = StringBuffer();
  String currentKey = "";
  for (var line in lines) {
    if (line.startsWith("  ")) {
      var spaceIndex = line.indexOf(" ", 2);
      var key = line.substring(2, spaceIndex);
      var lang = charNameKeysToBatchLocLang[key];
      var val = line.substring(spaceIndex + 1);
      if (langFilter != lang) {
        newCharNames.writeln(line);
        continue;
      }
      var loc = _lookupLocWithDuplicates(locMap, currentKey, visitedCounts);
      if (loc == null || loc == val) {
        newCharNames.writeln(line);
      }
      else {
        newCharNames.writeln("  $key $loc");
        hasChanges = true;
      }
    }
    else {
      if (line.isNotEmpty) {
        currentKey = line.substring(1);
        newCharNames.writeln(line);
      }
    }
  }

  if (hasChanges) {
    var newHexData = firstLine + utf8.encode(newCharNames.toString());
    var newHexStr = hex.encode(newHexData);
    var sizeEl = textParent!.getElement("size");
    sizeEl!.innerText = "0x${newHexData.length.toRadixString(16)}";
    for (var oldValue in textParent.findElements("value").toList())
      oldValue.remove();
    for (int i = 0; i < newHexStr.length; i += 64) {
      var valueEl = makeXmlElement(name: "value", text: newHexStr.substring(i, min(i + 64, newHexStr.length)));
      textParent.children.add(valueEl);
    }
    var newXmlStr = charNameXml.toPrettyString();
    await File(xml).writeAsString(newXmlStr);
    await xmlFileToYaxFile(xml);
    await repackPak(pakPath);
    datFilesToExport.add(locFile.datName);
  }
}

Future<void> _processMcd(BatchLocalizationFileData locFile, String datDir, List<String> datFilesToExport) async {
  var mcdPath = join(datDir, locFile.datName, locFile.fileName);
  McdData? mcd;
  try {
    mcd = await McdData.fromMcdFile(null, mcdPath);
    mcd.exportDatFunc = (path) async => datFilesToExport.add(basename(path));
    var locMap = locFile.asMap();
    var hasChanges = false;
    for (var event in mcd.events) {
      var loc = locMap[event.name.value];
      if (loc == null)
        continue;
      var locLines = loc.split("\n");
      for (var paragraph in event.paragraphs) {
        for (var (i, line) in paragraph.lines.indexed) {
          if (i >= locLines.length)
            break;
          var locLine = locLines[i];
          if (line.text.value != locLine) {
            line.text.value = locLine;
            hasChanges = true;
          }
        }
      }
    }

    if (hasChanges) {
      await mcd.save();
      datFilesToExport.add(locFile.datName);
      datFilesToExport.add(locFile.datName.replaceFirst(".dat", ".dtt"));
    }
  } finally {
    mcd?.dispose();
  }
}

String? _lookupLocWithDuplicates(Map<String, List<String>> locMap, String key, Map<String, int> visitedCounts) {
  var locs = locMap[key];
  if (locs == null || locs.isEmpty)
    return null;
  if (locs.length == 1)
    return locs[0];
  var lastReadAtIndex = visitedCounts[key] ?? -1;
  var readFromIndex = min(lastReadAtIndex + 1, locs.length - 1);
  visitedCounts[key] = readFromIndex;
  return locs[readFromIndex];
}

class BatchLocExportProgress extends ChangeNotifier {
  bool isRunning = false;
  int step = 0;
  int totalSteps = 2;
  String stepName = "";
  int file = 0;
  int totalFiles = 0;
  String? currentFile;
  List<String> messages = [];

  void reset() {
    isRunning = false;
    step = 0;
    totalSteps = 2;
    stepName = "";
    file = 0;
    totalFiles = 0;
    currentFile = null;
    messages.clear();
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }
}
