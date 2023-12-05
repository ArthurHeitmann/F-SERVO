import 'package:flutter/material.dart';

import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/preferencesData.dart';
import '../misc/preferencesEditor.dart';
import '../propEditors/otherFileTypes/effect/EstFileEditor.dart';
import '../propEditors/otherFileTypes/SaveSlotDataEditor.dart';
import '../propEditors/otherFileTypes/bnkPlaylistEditor/BnkPlaylistEditor.dart';
import '../propEditors/otherFileTypes/ftbEditor.dart';
import '../propEditors/otherFileTypes/genericTable/TableFileEditor.dart';
import '../propEditors/otherFileTypes/mcdEditor.dart';
import '../propEditors/otherFileTypes/wemFileEditor.dart';
import '../propEditors/otherFileTypes/wspFileEditor.dart';
import '../propEditors/otherFileTypes/wtaWtpEditor.dart';
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
  wem,
  wsp,
  bnkPlaylist,
  saveSlotData,
  wta,
  est,
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
    case FileType.wem:
      return WemFileEditor(key: Key(content.uuid), wem: content as WemFileData, topPadding: true,);
    case FileType.wsp:
      return WspFileEditor(key: Key(content.uuid), wsp: content as WspFileData);
    case FileType.bnkPlaylist:
      return BnkPlaylistEditor(playlist: content as BnkFilePlaylistData);
    case FileType.saveSlotData:
      return SaveSlotDataEditor(save: content as SaveSlotData);
    case FileType.wta:
      return WtaWtpEditor(file: content as WtaWtpData);
    case FileType.est:
      return EstFileEditor(file: content as EstFileData);
    case FileType.text:
      return TextFileEditor(key: Key(content.uuid), fileContent: content as TextFileData);
    default:
      return const Center(child: Text("No editor for this file type yet!"));
  }
}
