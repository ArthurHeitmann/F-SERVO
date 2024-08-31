
import 'dart:io';

import 'package:xml/xml.dart';

import '../../fileTypeUtils/xml/xmlExtension.dart';
import 'guessedData.dart';
import 'wwiseElement.dart';
import 'wwiseProjectGenerator.dart';
import 'wwiseUtils.dart';

abstract class WwiseElementBase {
  final String id;
  String? _name;
  String getFallbackName() => id;
  String get name => _name ?? initAndGetFallbackName();
  final WwiseProjectGenerator project;
  final List<WwiseElement> _children;
  Iterable<WwiseElement> get children => _children;
  WwiseElementBase? parent;
  final Set<String> parentBnks = {};
  final GuessedObjectData guessed;

  WwiseElementBase({required this.project, String? name, String? id, Iterable<WwiseElement>? children}) :
    id = id ?? project.idGen.uuid(),
    _name = name,
    _children = children is List<WwiseElement> ? children : (children?.toList() ?? []),
    guessed = GuessedObjectData(project) {
    project.putElement(this);
  }

  XmlElement toXml();

  Future<void> saveTo(String path) async {
    var doc = XmlDocument([
      XmlProcessing("xml", "version=\"1.0\" encoding=\"utf-8\""),
      toXml(),
    ]);
    await File(path).writeAsString(doc.toPrettyString());
  }

  void addChild(WwiseElement child) {
    _children.add(child);
    if (child.parent != null)
      throw Exception("Child already has a parent");
    child.parent = this;
  }

  addAllChildren(Iterable<WwiseElement> children) {
    for (var child in children) {
      addChild(child);
    }
  }

  sortChildren([int Function(WwiseElement a, WwiseElement b)? compare]) {
    _children.sort(compare);
  }

  void addGuessedFullPathFromId(Map<String, Map<int, String>> bnkToPath, int id, bool isConfident) {
    var paths = parentBnks
      .map((bnkName) => getObjectPath(bnkName, id, bnkToPath)?.join("/"))
      .whereType<String>()
      .toSet();
    if (paths.length > 1)
      project.log(WwiseLogSeverity.warning, "Multiple conflicting paths for $name (${paths.join(", ")})");
    var path = paths.firstOrNull;
    addGuessedFullPath(path, isConfident);
  }
  void addGuessedFullPath(String? path, bool isConfident) {
    var splitI = path?.lastIndexOf("/") ?? -1;
    if (splitI == -1)
      return;
    var objName = path!.substring(splitI + 1);
    var objParentPath = path.substring(0, splitI);
    guessed.name.addGuess(objName, isConfident);
    guessed.parentPath.addGuess(objParentPath, isConfident);
  }

  String initAndGetFallbackName() {
    _name ??= getFallbackName();
    return _name!;
  }
}
