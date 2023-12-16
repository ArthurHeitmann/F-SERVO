
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/smd/smdReader.dart';
import '../../../fileTypeUtils/smd/smdWriter.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../changesExporter.dart';
import '../../otherFileTypes/SmdFileData.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class SmdFileData extends OpenFileData {
  SmdData? smdData;

  SmdFileData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.smd, icon: Icons.subtitles);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var smdEntries = await readSmdFile(path);
    smdData?.dispose();
    smdData = SmdData.from(smdEntries, basenameWithoutExtension(path));
    smdData!.fileChangeNotifier.addListener(() {
      setHasUnsavedChanges(true);
    });

    await super.load();
  }

  @override
  Future<void> save() async {
    await saveSmd(smdData!.toEntries(), path);

    var datDir = dirname(path);
    changedDatFiles.add(datDir);

    await super.save();
  }

  @override
  void dispose() {
    smdData?.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = SmdFileData(name.value, path);
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.optionalInfo = optionalInfo;
    snapshot.loadingState.value = loadingState.value;
    snapshot.smdData = smdData?.takeSnapshot() as SmdData?;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as SmdFileData;
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
    if (content.smdData != null)
      smdData?.restoreWith(content.smdData as Undoable);
  }
}
