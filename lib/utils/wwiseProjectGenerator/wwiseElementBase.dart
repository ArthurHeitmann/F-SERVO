
import 'dart:io';

import 'package:xml/xml.dart';

import '../../fileTypeUtils/xml/xmlExtension.dart';
import 'wwiseElement.dart';
import 'wwiseProjectGenerator.dart';

abstract class WwiseElementBase {
  final String id;
  final String name;
  final WwiseProjectGenerator project;
  final List<WwiseElement> _children;
  Iterable<WwiseElement> get children => _children;
  final Set<String> parentBnks = {};

  WwiseElementBase({required this.project, required this.name, String? id, Iterable<WwiseElement>? children})
    : id = id ?? project.idGen.uuid(),
      _children = children is List<WwiseElement> ? children : (children?.toList() ?? []) {
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
  }

  addAllChildren(Iterable<WwiseElement> children) {
    for (var child in children) {
      addChild(child);
    }
  }

  sortChildren([int Function(WwiseElement a, WwiseElement b)? compare]) {
    _children.sort(compare);
  }
}
