import 'package:flutter/material.dart';

import '../../stateManagement/openFileTypes.dart';
import 'TextFileEditor.dart';
import 'XmlFileEditor.dart';

enum FileType {
  text,
  xml,
}

Widget makeFileEditor(OpenFileData content) {
  switch (content.type) {
    case FileType.xml:
      return XmlFileEditor(fileContent: content as XmlFileData);
    // case FileType.text:
    default:
      return TextFileEditor(fileContent: content as TextFileData);
  }
}
