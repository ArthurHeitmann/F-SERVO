
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../../fileTypeUtils/yax/japToEng.dart';
import '../utils.dart';
import 'wwiseElementBase.dart';
import 'wwiseProjectGenerator.dart';
import 'wwiseProperty.dart';

class WwiseElement extends WwiseElementBase {
  final String wuId;
  final String tagName;
  final int? shortId;
  final WwisePropertyList properties;
  final Map<String, String> additionalAttributes;
  final List<XmlElement> additionalChildren;
  final String comment;

  WwiseElement({
    required this.wuId,
    required super.project,
    required this.tagName,
    required super.name,
    super.id,
    this.shortId,
    int? shortIdHint,
    List<WwiseProperty>? properties,
    super.children,
    Map<String, String>? additionalAttributes,
    List<XmlElement>? additionalChildren,
    String? comment,
  }):
    properties = WwisePropertyList(properties ?? []),
    additionalAttributes = additionalAttributes ?? {},
    additionalChildren = additionalChildren ?? [],
    comment = comment ?? project.getComment(shortId ?? shortIdHint ?? 0) ?? ""
  {
    if (shortId != null || shortIdHint != null)
      project.putElement(this, idFnv: shortId ?? shortIdHint!);
  }

  factory WwiseElement.fromXml(String wuId, WwiseProjectGenerator project, XmlElement element) {
    var id = element.getAttribute("ID")!;
    var name = element.getAttribute("Name")!;
    var shortId = element.getAttribute("ShortID");
    var tagName = element.name.local;
    return WwiseElement(
      wuId: wuId,
      project: project,
      tagName: tagName,
      name: name,
      id: id,
      shortId: shortId != null ? int.parse(shortId) : null,
    );
  }

  @mustCallSuper
  void initNames() {
    for (var child in children) {
      child.initNames();
    }
    var guessedParentPath = guessed.parentPath.value;
    if (guessedParentPath != null && parent != null) {
      parent!.addGuessedFullPath(guessedParentPath, guessed.parentPath.isConfident);
    }
  }

  @mustCallSuper
  void initData() {
    for (var child in children) {
      child.initData();
    }
  }

  Map<String, String> getAdditionalAttributes() {
    return additionalAttributes;
  }

  List<XmlElement> getAdditionalChildren() {
    return additionalChildren;
  }

  @override
  XmlElement toXml() {
    return makeXmlElement(
      name: tagName,
      attributes: {
        "Name": name,
        "ID": id,
        if (shortId != null)
          "ShortID": shortId.toString(),
        ...getAdditionalAttributes(),
      },
      children: [
        if (comment.isNotEmpty)
          makeXmlElement(name: "Comment", text: japToEng[comment] ?? comment),
        if (properties.isNotEmpty)
          properties.toXml(),
        if (children.isNotEmpty)
          makeXmlElement(
            name: "ChildrenList",
            children: children.map((e) => e.toXml()).toList(),
          ),
        ...getAdditionalChildren(),
      ],
    );
  }
}
