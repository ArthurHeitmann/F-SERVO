
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../widgets/filesView/FileType.dart';
import '../../changesExporter.dart';
import '../../otherFileTypes/FtbFileData.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class FtbFileData extends OpenFileData {
  FtbData? ftbData;

  FtbFileData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.ftb, icon: Icons.subtitles);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    ftbData?.dispose();
    ftbData = await FtbData.fromFtbFile(path);
    await ftbData!.extractTextures();

    await super.load();
  }

  @override
  Future<void> save() async {
    await ftbData?.save();
    var datDir = dirname(path);
    changedDatFiles.add(datDir);
    await super.save();
  }

  @override
  void dispose() {
    ftbData?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    return this;
  }

  @override
  void restoreWith(Undoable snapshot) {
    // nothing to do
  }
}
