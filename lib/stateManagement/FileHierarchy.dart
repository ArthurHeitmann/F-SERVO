
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/fileTypeUtils/dat/datExtractor.dart';
import 'package:nier_scripts_editor/stateManagement/nestedNotifier.dart';
import 'package:path/path.dart' as path;

import '../fileTypeUtils/pak/pakExtractor.dart';

class HierarchyEntry extends NestedNotifier {
  String _name;
  final IconData? icon;
  final bool isSelectable;
  bool _isSelected = false;
  final bool isCollapsible;

  HierarchyEntry(this._name, this.isSelectable, this.isCollapsible, { this.icon })
    : super([]);

  String get name => _name;

  set name(String value) {
    _name = value;
    notifyListeners();
  }

  bool get isSelected => _isSelected;

  set isSelected(bool value) {
    _isSelected = value;
    notifyListeners();
  }
}

class FileHierarchyEntry extends HierarchyEntry {
  final String path;

  FileHierarchyEntry(String name, this.path, bool isCollapsible, { IconData? icon })
    : super(name, true, isCollapsible, icon: icon);
}

class ExtractableHierarchyEntry extends FileHierarchyEntry {
  final String extractedPath;

  ExtractableHierarchyEntry(String name, String filePath, this.extractedPath, bool isCollapsible, { IconData? icon })
    : super(name, filePath, isCollapsible, icon: icon);
}

class DatHierarchyEntry extends ExtractableHierarchyEntry {
  DatHierarchyEntry(String name, String path, String extractedPath)
    : super(name, path, extractedPath, true, icon: Icons.folder);
}

class PakHierarchyEntry extends ExtractableHierarchyEntry {
  PakHierarchyEntry(String name, String path, String extractedPath)
    : super(name, path, extractedPath, true, icon: Icons.source);
}

class HapGroupHierarchyEntry extends FileHierarchyEntry {
  HapGroupHierarchyEntry(String name, String path)
    : super(name, path, true, icon: Icons.workspaces);
}

class XmlScriptHierarchyEntry extends FileHierarchyEntry {
  XmlScriptHierarchyEntry(String name, String path)
    : super(name, path, false, icon: Icons.code);
}

class OpenHierarchyManager extends NestedNotifier<HierarchyEntry> {
  OpenHierarchyManager() : super([]);

  void openDat(String datPath) {
    var fileName = path.basename(datPath);
    var datFolder = path.dirname(datPath);
    var datExtractDir = path.join(datFolder, "nier2blender_extracted", fileName);
    if (!Directory(datExtractDir).existsSync()) {   // TODO: check if extracted folder actually contains all dat files
      extractDatFiles(datPath, extractPakFiles: true);
    }
    add(DatHierarchyEntry(fileName, datPath, datExtractDir));

    // TODO: search based on dat metadata
    for (var file in Directory(datExtractDir).listSync()) {
      if (file is File && file.path.endsWith(".pak")) {
        var pakPath = file.path;
        openPak(pakPath);
      }
    }
  }

  void openExtractedDat(String datDirPath) {
    var srcDatDir = path.dirname(path.dirname(datDirPath));
    var srcDatPath = path.join(srcDatDir, path.basename(datDirPath));
    openDat(srcDatPath);
  }

  void openPak(String pakPath) {
    var pakFolder = path.dirname(pakPath);
    var pakExtractDir = path.join(pakFolder, "pakExtracted", path.basename(pakPath));
    if (!Directory(pakExtractDir).existsSync()) {
      extractPakFile(pakPath, yaxToXml: true);
    }
    add(PakHierarchyEntry(pakPath.split(Platform.pathSeparator).last, pakPath, pakExtractDir));

    var pakInfoJsonPath = path.join(pakExtractDir, "pakInfo.json");
    var pakInfoJson = json.decode(File(pakInfoJsonPath).readAsStringSync());
    for (var yaxFile in pakInfoJson["files"]) {
      var xmlFile = yaxFile["name"].replaceAll(".yax", ".xml");
      var xmlFilePath = path.join(pakExtractDir, xmlFile);
      if (!File(xmlFilePath).existsSync()) {
        // TODO: display error message
      }
      add(XmlScriptHierarchyEntry(xmlFile, xmlFilePath));
    }
  }

  void openXmlScript(String xmlFilePath) {
    add(XmlScriptHierarchyEntry(path.basename(xmlFilePath), xmlFilePath));
  }
}

final openHierarchyManager = OpenHierarchyManager();
