import 'package:flutter/material.dart';

import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/preferencesData.dart';
import '../misc/preferencesEditor.dart';
import 'TextFileEditor.dart';
import 'XmlFileEditor.dart';

enum FileType {
  text,
  xml,
  preferences,
}

Widget makeFileEditor(OpenFileData content) {
  switch (content.type) {
    case FileType.xml:
      return XmlFileEditor(fileContent: content as XmlFileData);
    case FileType.preferences:
      return PreferencesEditor(prefs: content as PreferencesData);
    default:
      return TextFileEditor(fileContent: content as TextFileData);
  }
}
