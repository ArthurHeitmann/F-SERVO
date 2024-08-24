
import 'dart:io';

import 'package:path/path.dart';
import 'package:xml/xml.dart';

import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseElementBase.dart';
import '../wwiseProjectGenerator.dart';

class WwiseWorkUnit extends WwiseElementBase {
  final String path;
  final String tagName;
  final String name;
  final String workUnitId;
  final List<XmlElement> defaultChildren;
  final String _folder;

  WwiseWorkUnit({
    super.id,
    required super.project,
    required this.path,
    required this.tagName,
    required this.name,
    String? workUnitId,
    List<XmlElement>? defaultChildren,
    super. children,
  }) :
    workUnitId = workUnitId ?? project.idGen.uuid(),
    defaultChildren = defaultChildren ?? [],
    _folder = basename(dirname(path));

  static Future<WwiseWorkUnit> emptyFromXml(WwiseProjectGenerator project, String xmlPath) async {
    var doc = XmlDocument.parse(await File(xmlPath).readAsString());
    var root = doc.rootElement;
    var id = root.getAttribute("ID")!;
    var child = root.childElements.first;
    var tagName = child.name.local;
    var workUnit = child.childElements.first;
    var name = workUnit.getAttribute("Name")!;
    var wuId = workUnit.getAttribute("ID")!;
    var children = workUnit.childElements.toList();
    return WwiseWorkUnit(
      id: id,
      project: project,
      path: xmlPath,
      tagName: tagName,
      name: name,
      workUnitId: wuId,
      defaultChildren: children,
    );
  }

  void addChild(WwiseElement child, int id) {
    Iterable<String>? folders = project.bnkFolders[id];
    if (folders == null || folders.isEmpty) {
      children.add(child);
      return;
    }
    if (folders.first == name || folders.first == _folder) {
      folders = folders.skip(1);
    }
    _addChild(child, folders, this);
  }

  void _addChild(WwiseElement child, Iterable<String> folders, WwiseElementBase parent) {
    if (folders.length <= 1) {
      parent.children.add(child);
      return;
    }
    var folderName = folders.first;
    var folder = parent.children
      .whereType<_WwiseFolder>()
      .where((f) => f.name == folderName)
      .firstOrNull;
    if (folder == null) {
      folder = _WwiseFolder(project: project, wuId: id, name: folderName);
      parent.children.add(folder);
    }
    _addChild(child, folders.skip(1), folder);
  }

  @override
  XmlElement toXml() {
    return makeXmlElement(
      name: "WwiseDocument",
      attributes: {
        "Type": "WorkUnit",
        "ID": id,
        "SchemaVersion": "54",
      },
      children: [
        makeXmlElement(
          name: tagName,
          children: [WwiseElement(
            wuId: id,
            project: project,
            tagName: "WorkUnit",
            name: name,
            id: workUnitId,
            additionalAttributes: {
              "PersistMode": "Standalone",
            },
            children: children,
          ).toXml()]
        ),
      ]
    );
  }

  Future<void> save() async {
    await saveTo(path);
  }
}

class _WwiseFolder extends WwiseElement {
  _WwiseFolder({required super.project, required super.wuId, required super.name, super.children}) : super(
    tagName: "Folder",
    shortId: project.idGen.shortId(),
  );
}
