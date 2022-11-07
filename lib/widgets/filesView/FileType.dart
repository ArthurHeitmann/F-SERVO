import 'package:flutter/material.dart';

import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/preferencesData.dart';
import '../misc/preferencesEditor.dart';
import '../propEditors/otherFileTypes/ftbEditor.dart';
import '../propEditors/otherFileTypes/genericTable/TableFileEditor.dart';
import '../propEditors/otherFileTypes/mcdEditor.dart';
import 'TextFileEditor.dart';
import 'XmlFileEditor.dart';

enum FileType {
  text,
  xml,
  preferences,
  tmd,
  smd,
  mcd,
  ftb,
}

Widget makeFileEditor(OpenFileData content) {
  switch (content.type) {
    case FileType.xml:
      return XmlFileEditor(key: Key(content.uuid), fileContent: content as XmlFileData);
    case FileType.preferences:
      return PreferencesEditor(key: Key(content.uuid), prefs: content as PreferencesData);
    case FileType.tmd:
      return TableFileEditor(key: Key(content.uuid), file: content, getTableConfig: () => (content as TmdFileData).tmdData!);
    case FileType.smd:
      return TableFileEditor(key: Key(content.uuid), file: content, getTableConfig: () => (content as SmdFileData).smdData!);
    case FileType.mcd:
      return McdEditor(key: Key(content.uuid), file: content as McdFileData);
    case FileType.ftb:
      return FtbEditor(key: Key(content.uuid), file: content as FtbFileData);
    default:
      return TextFileEditor(key: Key(content.uuid), fileContent: content as TextFileData);
  }
}
