
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../../../utils/utils.dart';
import '../../../../widgets/filesView/FileType.dart';
import '../../../Property.dart';
import '../../../changesExporter.dart';
import '../../../hierarchy/FileHierarchy.dart';
import '../../../hierarchy/types/XmlScriptHierarchyEntry.dart';
import '../../../undoable.dart';
import '../../openFileTypes.dart';
import 'xmlProps/xmlProp.dart';

class XmlFileData extends OpenFileData {
  XmlProp? _root;
  XmlProp? get root => _root;
  NumberProp? pakType;

  XmlFileData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.xml, icon: Icons.description);

  void _onNameChange() {
    var xmlName = _root!.get("name")!.value.toString();

    secondaryName.value = xmlName;

    var hierarchyEntry = openHierarchyManager
        .children
        .findRecWhere((entry) => entry is XmlScriptHierarchyEntry && entry.path == path) as XmlScriptHierarchyEntry?;
    if (hierarchyEntry != null)
      hierarchyEntry.hapName.value = xmlName;
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;
    var text = await File(path).readAsString();
    var doc = XmlDocument.parse(text);
    _root?.dispose();
    _root = XmlProp.fromXml(doc.firstElementChild!, file: uuid, parentTags: []);
    var nameProp = _root!.get("name");
    if (nameProp != null) {
      nameProp.value.addListener(_onNameChange);
      secondaryName.value = nameProp.value.toString();
    }

    var pakInfoFileData = await getPakInfoFileData(path);
    pakType = null;
    if (pakInfoFileData != null) {
      pakType?.dispose();
      pakType = NumberProp(pakInfoFileData["type"], true);
      pakType!.addListener(updatePakType);
    }

    await super.load();
  }

  Future<void> updatePakType() async {
    await updatePakInfoFileData(path, (fileData) => fileData["type"] = pakType!.value.toInt());

    var pakDir = dirname(path);
    changedPakFiles.add(pakDir);
    await processChangedFiles();
  }

  @override
  Future<void> save() async {
    if (_root == null) {
      await super.save();
      return;
    }
    var doc = XmlDocument();
    doc.children.add(XmlDeclaration([XmlAttribute(XmlName("version"), "1.0"), XmlAttribute(XmlName("encoding"), "utf-8")]));
    doc.children.add(_root!.toXml());
    var xmlStr = "${doc.toXmlString(pretty: true, indent: '\t')}\n";
    await File(path).writeAsString(xmlStr);
    await super.save();
    changedXmlFiles.add(this);
  }

  @override
  void dispose() {
    _root?.dispose();
    _root?.get("name")?.value.removeListener(_onNameChange);
    pakType?.removeListener(updatePakType);
    pakType?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = XmlFileData(name.value, path);
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot._root = _root != null ? _root!.takeSnapshot() as XmlProp : null;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as XmlFileData;
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
    if (content._root != null)
      _root?.restoreWith(content._root as Undoable);
  }
}
