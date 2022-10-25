import 'package:flutter/material.dart';

import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/preferencesData.dart';
import '../misc/preferencesEditor.dart';
import '../propEditors/otherFileTypes/genericTable/TableFileEditor.dart';
import 'TextFileEditor.dart';
import 'XmlFileEditor.dart';

enum FileType {
  text,
  xml,
  preferences,
  tmd,
  smd,
}

Widget makeFileEditor(OpenFileData content) {
  switch (content.type) {
    case FileType.xml:
      return XmlFileEditor(fileContent: content as XmlFileData);
    case FileType.preferences:
      return PreferencesEditor(prefs: content as PreferencesData);
    case FileType.tmd:
      return TableFileEditor(file: content, getTableConfig: () => (content as TmdFileData).tmdData!);
    case FileType.smd:
      return TableFileEditor(file: content, getTableConfig: () => (content as SmdFileData).smdData!);
    default:
      return TextFileEditor(fileContent: content as TextFileData);
  }
}
