
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../../fileTypeUtils/bxm/bxmReader.dart';
import '../../../fileTypeUtils/bxm/bxmWriter.dart';
import '../../../utils/utils.dart';
import '../../../utils/xmlLineParser.dart';
import '../openFileTypes.dart';
import 'TextFileData.dart';

class BxmFileData extends TextFileData {
  String? _xmlPath;
  @override
  String get vsCodePath => _xmlPath ?? path;

  BxmFileData(super.name, super.path, { super.secondaryName, IconData? icon, super.iconColor, super.initText })
      : super(icon: icon ?? Icons.text_fields);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;
    try {
      var xmlPath = await getXmlPath();
      text.value = await File(xmlPath).readAsString();
    } catch (e, s) {
      text.value = "[Error loading file]";
      print("$e\n$s");
    }
    loadingState.value = LoadingState.loaded;
    setHasUnsavedChanges(false);
    onUndoableEvent(immediate: true);
  }

  @override
  Future<void> save() async {
    var xmlPath = await getXmlPath();
    await File(xmlPath).writeAsString(text.value);
    try {
      await convertXmlToBxmFile(xmlPath, path);
    } on XmlException catch (e) {
      // try get useful error message
      try {
        parseXmlWL(text.value);
      } on XmlWlParseException catch (e) {
        showToast("Error in XML: ${e.toString()}");
        return;
      // ignore: empty_catches
      } catch (e) {
      }
      showToast("Error in XML: ${e.toString()}");
    }
    setHasUnsavedChanges(false);
  }

  Future<String> getXmlPath() async {
    if (_xmlPath != null)
      return _xmlPath!;
    var xmlPath1 = "$path.xml";
    if (await File(xmlPath1).exists())
      return _xmlPath = xmlPath1;
    var xmlPath2 = "${withoutExtension(path)}.xml";
    if (await File(xmlPath2).exists())
      return _xmlPath = xmlPath2;
    await convertBxmFileToXml(path, xmlPath1);
    return _xmlPath = xmlPath1;
  }

  @override
  @protected
  BxmFileData copyBase() {
    return BxmFileData(name.value, path, initText: text.value);
  }
}
