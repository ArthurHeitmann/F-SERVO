import 'package:flutter/material.dart';

import '../../stateManagement/openFiles/openFileTypes.dart';
import '../../stateManagement/openFiles/types/BnkFilePlaylistData.dart';
import '../../stateManagement/openFiles/types/EstFileData.dart';
import '../../stateManagement/openFiles/types/FtbFileData.dart';
import '../../stateManagement/openFiles/types/McdFileData.dart';
import '../../stateManagement/openFiles/types/SaveSlotData.dart';
import '../../stateManagement/openFiles/types/SmdFileData.dart';
import '../../stateManagement/openFiles/types/TextFileData.dart';
import '../../stateManagement/openFiles/types/TmdFileData.dart';
import '../../stateManagement/openFiles/types/WemFileData.dart';
import '../../stateManagement/openFiles/types/WspFileData.dart';
import '../../stateManagement/openFiles/types/WtaWtpData.dart';
import '../../stateManagement/openFiles/types/xml/XmlFileData.dart';
import '../../stateManagement/preferencesData.dart';
import '../misc/preferencesEditor.dart';
import 'types/SaveSlotDataEditor.dart';
import 'types/TextFileEditor.dart';
import 'types/bnkPlaylistEditor/BnkPlaylistEditor.dart';
import 'types/effect/EstFileEditor.dart';
import 'types/fonts/FontsManager.dart';
import 'types/fonts/ftbEditor.dart';
import 'types/fonts/mcdEditor.dart';
import 'types/genericTable/TableFileEditor.dart';
import 'types/wem/wemFileEditor.dart';
import 'types/wem/wspFileEditor.dart';
import 'types/wtaWtpEditor.dart';
import 'types/xml/XmlFileEditor.dart';

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
  fontSettings,
  none,
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
    case FileType.fontSettings:
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: FontsManager(),
      );
    case FileType.text:
      return TextFileEditor(key: Key(content.uuid), fileContent: content as TextFileData);
    default:
      return const Center(child: Text("No editor for this file type yet!"));
  }
}
