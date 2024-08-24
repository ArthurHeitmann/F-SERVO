
import 'dart:io';

import 'package:xml/xml.dart';

import '../../fileTypeUtils/xml/xmlExtension.dart';
import 'wwiseElement.dart';
import 'wwiseProjectGenerator.dart';

abstract class WwiseElementBase {
  final String id;
  final WwiseProjectGenerator project;
  final List<WwiseElement> children;

  WwiseElementBase({required this.project, String? id, List<WwiseElement>? children})
    : id = id ?? project.idGen.uuid(),
      children = children ?? [] {
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
}
