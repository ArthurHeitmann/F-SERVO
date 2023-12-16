
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class TextFileData extends OpenFileData {
  late final StringProp text;
  int cursorOffset = 0;

  TextFileData(super.name, super.path, { super.secondaryName, IconData? icon, super.iconColor })
      : super(type: FileType.text, icon: icon ?? Icons.text_fields) {
    text = StringProp("Loading...", fileId: uuid);
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;
    try {
      text.value = await File(path).readAsString();
    } catch (e) {
      text.value = "[Error loading file]";
      print(e);
    }
    await super.load();
  }

  @override
  Future<void> save() async {
    await File(path).writeAsString(text.value);
    setHasUnsavedChanges(false);
  }

  @protected
  TextFileData copyBase() {
    return TextFileData(name.value, path);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = copyBase();
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.text.value = text.value;
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
