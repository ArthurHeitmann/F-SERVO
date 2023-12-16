
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/tmd/tmdReader.dart';
import '../../../fileTypeUtils/tmd/tmdWriter.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../changesExporter.dart';
import '../../otherFileTypes/TmdFileData.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class TmdFileData extends OpenFileData {
  TmdData? tmdData;

  TmdFileData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.tmd, icon: Icons.subtitles);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var tmdEntries = await readTmdFile(path);
    tmdData?.dispose();
    tmdData = TmdData.from(tmdEntries, basenameWithoutExtension(path));
    tmdData!.fileChangeNotifier.addListener(() {
      setHasUnsavedChanges(true);
    });

    await super.load();
  }

  @override
  Future<void> save() async {
    await saveTmd(tmdData!.toEntries(), path);

    var datDir = dirname(path);
    changedDatFiles.add(datDir);

    await super.save();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = TmdFileData(name.value, path);
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.tmdData = tmdData?.takeSnapshot() as TmdData?;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as TmdFileData;
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
    if (content.tmdData != null)
      tmdData?.restoreWith(content.tmdData as Undoable);
  }

  @override
  void dispose() {
    tmdData?.dispose();
    super.dispose();
  }
}
