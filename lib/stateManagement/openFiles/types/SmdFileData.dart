// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/smd/smdReader.dart';
import '../../../fileTypeUtils/smd/smdWriter.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../../widgets/filesView/types/genericTable/tableEditor.dart';
import '../../Property.dart';
import '../../changesExporter.dart';
import '../../hasUuid.dart';
import '../../listNotifier.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import '../openFilesManager.dart';


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
    smdData = SmdData.from(smdEntries, basenameWithoutExtension(path), uuid);
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


class SmdEntryData with HasUuid, Undoable {
  final StringProp id;
  final StringProp text;
  final ChangeNotifier _anyChangeNotifier;

  SmdEntryData({ required this.id, required this.text, required ChangeNotifier anyChangeNotifier })
      : _anyChangeNotifier = anyChangeNotifier {
    id.addListener(_anyChangeNotifier.notifyListeners);
    text.addListener(_anyChangeNotifier.notifyListeners);
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = SmdEntryData(
      id: id.takeSnapshot() as StringProp,
      text: text.takeSnapshot() as StringProp,
      anyChangeNotifier: _anyChangeNotifier,
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as SmdEntryData;
    id.restoreWith(data.id);
    text.restoreWith(data.text);
  }
}

class SmdData extends ListNotifier<SmdEntryData> with CustomTableConfig, Undoable {
  final ChangeNotifier fileChangeNotifier;

  SmdData(List<SmdEntryData> entries, String fileName, OpenFileId fileId, this.fileChangeNotifier)
    : super(entries, fileId: fileId) {
    name = fileName;
    columnNames = ["ID", "Text"];
    columnFlex = [1, 2];
    rowCount = NumberProp(entries.length, true, fileId: fileId);
  }

  SmdData.from(List<SmdEntry> rawEntries, String fileName, OpenFileId fileId)
    : fileChangeNotifier = ChangeNotifier(),
      super([], fileId: fileId) {
    addAll(rawEntries.map((e) {
      var idProp = StringProp(e.id, fileId: fileId);
      var textProp = StringProp(e.text, fileId: fileId);
      return SmdEntryData(
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

  List<SmdEntry> toEntries()
  => List.generate(length, (i) => SmdEntry(this[i].id.value, i * 10, this[i].text.value));

  @override
  void onRowAdd() {
    var idProp = StringProp("ID", fileId: fileId);
    var textProp = StringProp("Text", fileId: fileId);
    add(SmdEntryData(
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
        PropCellConfig(prop: entry.text, allowMultiline: true),
      ],
    );
  }

  @override
  void updateRowWith(int index, List<String?> values) {
    if (index > length) {
      assert(index == length);
      var idProp = StringProp(values[0]!, fileId: fileId);
      var textProp = StringProp(values[1]!, fileId: fileId);
      add(SmdEntryData(
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
    var snapshot = SmdData(
      map((e) => e.takeSnapshot() as SmdEntryData).toList(),
      name,
      fileId!,
      fileChangeNotifier,
    );
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as SmdData;
    updateOrReplaceWith(data.toList(), (e) => e.takeSnapshot() as SmdEntryData);
    rowCount.value = length;
  }
}
