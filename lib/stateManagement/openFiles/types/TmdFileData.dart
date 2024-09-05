// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/tmd/tmdReader.dart';
import '../../../fileTypeUtils/tmd/tmdWriter.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../../widgets/filesView/types/genericTable/tableEditor.dart';
import '../../../widgets/propEditors/propTextField.dart';
import '../../Property.dart';
import '../../changesExporter.dart';
import '../../hasUuid.dart';
import '../../listNotifier.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import '../openFilesManager.dart';


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
    tmdData = TmdData.from(tmdEntries, basenameWithoutExtension(path), uuid);
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

class TmdEntryData with HasUuid, Undoable {
  final StringProp id;
  final StringProp text;
  final ChangeNotifier _anyChangeNotifier;

  TmdEntryData({ required this.id, required this.text, required ChangeNotifier anyChangeNotifier })
      : _anyChangeNotifier = anyChangeNotifier {
    id.addListener(_anyChangeNotifier.notifyListeners);
    text.addListener(_anyChangeNotifier.notifyListeners);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = TmdEntryData(
      id: id.takeSnapshot() as StringProp,
      text: text.takeSnapshot() as StringProp,
      anyChangeNotifier: _anyChangeNotifier,
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as TmdEntryData;
    id.restoreWith(data.id);
    text.restoreWith(data.text);
  }
}

class TmdData extends ListNotifier<TmdEntryData> with CustomTableConfig, Undoable {
  final ChangeNotifier fileChangeNotifier;

  TmdData(List<TmdEntryData> entries, String fileName, OpenFileId fileId, this.fileChangeNotifier)
      : super(entries, fileId: fileId) {
    name = fileName;
    columnNames = ["ID", "Text"];
    columnFlex = [1, 2];
    rowCount = NumberProp(entries.length, true, fileId: fileId);
  }

  TmdData.from(List<TmdEntry> rawEntries, String fileName, OpenFileId fileId)
      : fileChangeNotifier = ChangeNotifier(),
      super([], fileId: fileId) {
    addAll(rawEntries.map((e) {
      var idProp = StringProp(e.id, fileId: fileId);
      var textProp = StringProp(e.text, fileId: fileId);
      return TmdEntryData(
        id: idProp,
        text: textProp,
        anyChangeNotifier: fileChangeNotifier,
      );
    }));
    name = fileName;
    columnNames = ["ID", "Text"];
    columnFlex = [1, 2];
    rowCount = NumberProp(rawEntries.length, true, fileId: fileId);
  }

  List<TmdEntry> toEntries()
  => map((e) => TmdEntry.fromStrings(e.id.value, e.text.value))
      .toList();

  @override
  void onRowAdd() {
    var idProp = StringProp("ID", fileId: fileId);
    var textProp = StringProp("Text", fileId: fileId);
    add(TmdEntryData(
      id: idProp,
      text: textProp,
      anyChangeNotifier: fileChangeNotifier,
    ));
    rowCount.value++;
    fileChangeNotifier.notifyListeners();
  }

  @override
  void onRowRemove(int index) {
    removeAt(index);
    rowCount.value--;
    fileChangeNotifier.notifyListeners();
  }

  @override
  RowConfig rowPropsGenerator(int index) {
    var entry = this[index];
    return RowConfig(
      key: Key(entry.uuid),
      cells: [
        PropCellConfig(prop: entry.id),
        PropCellConfig(prop: entry.text, options: const PropTFOptions(isMultiline: true)),
      ],
    );
  }

  @override
  void updateRowWith(int index, List<String?> values) {
    if (index > length) {
      assert(index == length);
      var idProp = StringProp(values[0]!, fileId: fileId);
      var textProp = StringProp(values[1]!, fileId: fileId);
      add(TmdEntryData(
        id: idProp,
        text: textProp,
        anyChangeNotifier: fileChangeNotifier,
      ));
      rowCount.value++;
      return;
    }
    var entry = this[index];
    entry.id.value = values[0] ?? "";
    entry.text.value = values[1] ?? "";
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = TmdData(
      map((e) => e.takeSnapshot() as TmdEntryData).toList(),
      name,
      fileId!,
      fileChangeNotifier,
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as TmdData;
    updateOrReplaceWith(data.toList(), (e) => e.takeSnapshot() as TmdEntryData);
    rowCount.value = length;
  }
}
