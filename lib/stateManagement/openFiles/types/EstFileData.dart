
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../widgets/filesView/FileType.dart';
import '../../changesExporter.dart';
import '../../listNotifier.dart';
import '../../otherFileTypes/EstFileData.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class EstFileData extends OpenFileData {
  late final EstData estData;

  EstFileData(super.name, super.path, { super.secondaryName, EstData? estData })
      : super(type: FileType.est, icon: Icons.subtitles) {
    this.estData = estData ?? EstData(ValueListNotifier([]), uuid);
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    await estData.loadFromEstFile(path);
    estData.onAnyChange.addListener(_onAnyChange);

    await super.load();
  }

  @override
  Future<void> save() async {
    await estData.save(path);
    var datDir = dirname(path);
    changedDatFiles.add(datDir);
    await super.save();
  }

  void _onAnyChange() {
    setHasUnsavedChanges(true);
    undoHistoryManager.onUndoableEvent();
  }

  @override
  void dispose() {
    estData.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = EstFileData(name.value, path, estData: estData.takeSnapshot() as EstData);
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as EstFileData;
    estData.restoreWith(content.estData);
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
  }
}
