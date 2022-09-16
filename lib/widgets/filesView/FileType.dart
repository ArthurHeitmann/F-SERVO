import 'package:flutter/material.dart';

import '../../stateManagement/openFileContents.dart';
import 'TextFileEditor.dart';
import 'XmlFileEditor.dart';

enum FileType {
  text,
  xml,
}

Widget makeFileEditor(FileContent content) {
  switch (content.id.type) {
    case FileType.xml:
      return XmlFileEditor(fileContent: content as XmlFileContent);
    // case FileType.text:
    default:
      return TextFileEditor(fileContent: content as TextFileContent);
  }
}
