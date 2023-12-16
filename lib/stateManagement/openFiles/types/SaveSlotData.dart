
import 'package:flutter/material.dart';

import '../../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../otherFileTypes/SlotDataDat.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class SaveSlotData extends OpenFileData {
  SlotDataDat? slotData;

  SaveSlotData(String name, String path, { super.secondaryName })
      : super(type: FileType.saveSlotData, name, path, icon: Icons.save) {
    canBeReloaded = false;
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var bytes = await ByteDataWrapper.fromFile(path);
    slotData?.dispose();
    slotData = SlotDataDat.read(bytes, uuid);
    for (var prop in slotData!.allProps())
      prop.addListener(_onPropChanged);

    await super.load();
  }

  void _onPropChanged() {
    setHasUnsavedChanges(true);
  }

  @override
  Future<void> save() async {
    if (loadingState.value != LoadingState.loaded)
      return;

    var bytes = await ByteDataWrapper.fromFile(path);
    slotData!.write(bytes);
    await backupFile(path);
    await bytes.save(path);

    await super.save();
  }

  @override
  void dispose() {
    super.dispose();
    slotData?.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = SaveSlotData(name.value, path);
    snapshot.optionalInfo = optionalInfo;
    snapshot.slotData = slotData?.takeSnapshot() as SlotDataDat?;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as SaveSlotData;
    if (content.slotData != null)
      slotData?.restoreWith(content.slotData!);
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
  }
}
