// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';

import '../../fileTypeUtils/tmd/tmdReader.dart';
import '../../widgets/propEditors/otherFileTypes/genericTable/tableEditor.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../nestedNotifier.dart';
import '../undoable.dart';

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

class TmdData extends NestedNotifier<TmdEntryData> with CustomTableConfig, Undoable {
  final ChangeNotifier fileChangeNotifier;

  TmdData(List<TmdEntryData> entries, String fileName, this.fileChangeNotifier)
    : super(entries) {
      name = fileName;
      columnNames = ["ID", "Text"];
      columnFlex = [1, 2];
      rowCount = NumberProp(entries.length, true);
    }

  TmdData.from(List<TmdEntry> rawEntries, String fileName)
    : fileChangeNotifier = ChangeNotifier(),
    super([]) {
    addAll(rawEntries.map((e) {
      var idProp = StringProp(e.id);
      var textProp = StringProp(e.text);
      return TmdEntryData(
        id: idProp,
        text: textProp,
        anyChangeNotifier: fileChangeNotifier,
      );
    }));
    name = fileName;
    columnNames = ["ID", "Text"];
    columnFlex = [1, 2];
    rowCount = NumberProp(rawEntries.length, true);
  }

  List<TmdEntry> toEntries() 
    => map((e) => TmdEntry.fromStrings(e.id.value, e.text.value))
    .toList();

  @override
  void onRowAdd() {
    var idProp = StringProp("ID");
    var textProp = StringProp("Text");
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
        PropCellConfig(prop: entry.text, allowMultiline: true),
      ],
    );
  }
  
  @override
  void updateRowWith(int index, List<String?> values) {
    if (index > length) {
      assert(index == length);
      var idProp = StringProp(values[0]!);
      var textProp = StringProp(values[1]!);
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
