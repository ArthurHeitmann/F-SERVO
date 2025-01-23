
import 'package:flutter/material.dart';

import '../../../widgets/filesView/FileType.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import 'McdFileData.dart';

class FontSettingsDummy extends OpenFileData {
  FontSettingsDummy() : super("Font Settings", "", type: FileType.fontSettings, icon: Icons.text_fields) {
    canBeReloaded = false;
    if (McdData.availableFonts.isEmpty)
      McdData.loadAvailableFonts();
  }

  @override
  void restoreWith(Undoable snapshot) {
  }

  @override
  Undoable takeSnapshot() {
    return FontSettingsDummy();
  }
}
