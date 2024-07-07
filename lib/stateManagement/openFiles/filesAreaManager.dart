import 'package:flutter/foundation.dart';

import '../../main.dart';
import '../../utils/Disposable.dart';
import '../../utils/utils.dart';
import '../../widgets/misc/confirmCancelDialog.dart';
import '../hasUuid.dart';
import '../listNotifier.dart';
import '../miscValues.dart';
import '../undoable.dart';
import 'openFileTypes.dart';
import 'openFilesManager.dart';

class FilesAreaManager with HasUuid, Undoable implements Disposable {
  final ListNotifier<OpenFileData> _files = ValueListNotifier([], fileId: null);
  IterableNotifier<OpenFileData> get files => _files;
  final ValueNotifier<OpenFileData?> _currentFile = ValueNotifier(null);
  ValueListenable<OpenFileData?> get currentFile => _currentFile;

  FilesAreaManager();

  setCurrentFile(OpenFileData? value) {
    assert(value == null || files.contains(value));
    if (value == _currentFile.value) return;
    _currentFile.value = value;

    if (this == areasManager.activeArea.value)
      windowTitle.value = currentFile.value?.displayName ?? "";
    else
      windowTitle.value = "";
  }

  void switchToClosestFile() {
    if (files.length <= 1) {
      setCurrentFile(null);
      return;
    }

    var index = files.indexOf(currentFile.value!);
    if (index + 1 == files.length)
      index--;
    else
      index++;
    setCurrentFile(files[index]);
  }

  Future<void> closeFile(OpenFileData file, { bool releaseHidden = false }) async {
    if (file.hasUnsavedChanges.value) {
      var answer = await confirmOrCancelDialog(
        getGlobalContext(),
        title: "Save changes?",
        body: "${file.name.value} has unsaved changes",
        yesText: "Save",
        noText: "Discard",
      );
      if (answer == true)
        await file.save();
      else if (answer == false) {
        file.setHasUnsavedChanges(false);
        try {
          await file.reload();
        } catch (e, stackTrace) {
          print("Error reloading file: $e");
          print(stackTrace);
        }
      } else if (answer == null)
        return;
    }
    if (file.keepOpenAsHidden && !releaseHidden)
      areasManager.hiddenArea._files.add(file);
    else if (releaseHidden) {
      areasManager.hiddenArea.removeFile(file);
      // TODO remove from areasManager
    }

    if (currentFile.value == file)
      switchToClosestFile();
    if (!releaseHidden || this != areasManager.hiddenArea)
      removeFile(file);

    if (files.isEmpty && areasManager.areas.length > 1)
      areasManager.removeArea(this);
    areasManager.onFileRemoved(file.uuid);
  }

  void closeAll() {
    var listCopy = List.from(files);
    for (var file in listCopy)
      closeFile(file);
  }

  void closeOthers(OpenFileData file) {
    var listCopy = List.from(files);
    for (var otherFile in listCopy)
      if (otherFile != file)
        closeFile(otherFile);
  }

  void closeToTheLeft(OpenFileData file) {
    var listCopy = List.from(files);
    int index = listCopy.indexOf(file);
    for (int i = 0; i < index; i++)
      closeFile(listCopy[i]);
  }

  void closeToTheRight(OpenFileData file) {
    var listCopy = List.from(files);
    int index = listCopy.indexOf(file);
    for (int i = index + 1; i < listCopy.length; i++)
      closeFile(listCopy[i]);
  }

  void moveToRightView(OpenFileData file) {
    int areaIndex = areasManager.areas.indexOf(this);
    FilesAreaManager rightArea;
    if (areaIndex >= areasManager.areas.length - 1) {
      if (files.length == 1)
        return;
      rightArea = FilesAreaManager();
      areasManager.addArea(rightArea);
    }
    else {
      rightArea = areasManager.areas[areaIndex + 1];
    }
    if (_currentFile.value == file)
      switchToClosestFile();
    rightArea._files.add(file);
    removeFile(file);
    rightArea.setCurrentFile(file);

    if (files.isEmpty) {
      areasManager.removeArea(this);
    }
  }

  void moveToLeftView(OpenFileData file) {
    int areaIndex = areasManager.areas.indexOf(this);
    int leftAreaIndex = areaIndex - 1;
    FilesAreaManager leftArea;
    if (leftAreaIndex < 0 || leftAreaIndex >= areasManager.areas.length) {
      if (files.length == 1)
        return;
      leftArea = FilesAreaManager();
      areasManager.insertArea(clamp(leftAreaIndex, 0, areasManager.areas.length), leftArea);
    }
    else {
      leftArea = areasManager.areas[leftAreaIndex];
    }
    if (currentFile.value == file)
      switchToClosestFile();
    leftArea._files.add(file);
    removeFile(file);
    leftArea.setCurrentFile(file);

    if (files.isEmpty) {
      areasManager.removeArea(this);
    }
  }

  void switchToNextFile() {
    if (files.length <= 1) return;
    int nextIndex = (files.indexOf(currentFile.value!) + 1) % files.length;
    setCurrentFile(files[nextIndex]);
  }

  void switchToPreviousFile() {
    if (files.length <= 1) return;
    int nextIndex = (files.indexOf(currentFile.value!) - 1) % files.length;
    if (nextIndex < 0)
      nextIndex += files.length;
    setCurrentFile(files[nextIndex]);
  }

  Future<void> saveAll() async {
    try {
      await Future.wait(
          files.where((file) => file.hasUnsavedChanges.value)
              .map((file) => file.save()));
    } catch (e, s) {
      print("Error while saving all files");
      print("$e\n$s");
      rethrow;
    }
  }

  void addFile(OpenFileData child) {
    _files.add(child);
  }

  void moveFile(int from, int to) {
    _files.move(from, to);
  }

  void removeFile(OpenFileData child) {
    _files.remove(child);
    if (areasManager.getAreaOfFile(child, true) == null)
      child.dispose();
  }

  @override
  void dispose() {
    for (var file in files.toList())
      removeFile(file);
    _currentFile.dispose();
    _files.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = FilesAreaManager();
    snapshot.overrideUuid(uuid);
    snapshot._files.replaceWith(files.map((entry) => entry.takeSnapshot() as OpenFileData).toList());
    snapshot.setCurrentFile(_currentFile.value != null ? snapshot.files[files.indexOf(_currentFile.value!)] : null);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as FilesAreaManager;
    _files.updateOrReplaceWith(entry.files.toList(), (obj) => obj.takeSnapshot() as OpenFileData);
    if (entry._currentFile.value != null)
      setCurrentFile(files.where((file) => file.uuid == entry._currentFile.value!.uuid).first);
    else
      setCurrentFile(null);
  }
}
