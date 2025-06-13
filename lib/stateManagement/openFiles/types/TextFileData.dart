

import 'package:flutter/material.dart';

import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import '../../../fileSystem/FileSystem.dart';

class TextFileData extends OpenFileData {
  late final StringProp text;
  int cursorOffset = 0;

  TextFileData(super.name, super.path, { super.secondaryName, IconData? icon, super.iconColor, String? initText })
      : super(type: FileType.text, icon: icon ?? Icons.text_fields) {
    text = StringProp(initText ?? "Loading...", fileId: uuid);
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;
    try {
      text.value = await FS.i.readAsString(path);
    } catch (e, s) {
      text.value = "[Error loading file]";
      print("$e\n$s");
    }
    await super.load();
  }

  @protected
  TextFileData copyBase() {
    return TextFileData(name.value, path, initText: text.value);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = copyBase();
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.cursorOffset = cursorOffset;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as TextFileData;
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
    text.value = content.text.value;
    cursorOffset = content.cursorOffset;
  }
}
