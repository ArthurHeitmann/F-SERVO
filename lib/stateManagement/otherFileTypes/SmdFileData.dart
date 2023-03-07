// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';

import '../../fileTypeUtils/smd/smdReader.dart';
import '../../widgets/propEditors/otherFileTypes/genericTable/tableEditor.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../listNotifier.dart';
import '../undoable.dart';

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

  SmdData(List<SmdEntryData> entries, String fileName, this.fileChangeNotifier)
    : super(entries) {
      name = fileName;
      columnNames = ["ID", "Text"];
      columnFlex = [1, 2];
      rowCount = NumberProp(entries.length, true);
    }

  SmdData.from(List<SmdEntry> rawEntries, String fileName)
    : fileChangeNotifier = ChangeNotifier(),
    super([]) {
    addAll(rawEntries.map((e) {
      var idProp = StringProp(e.id);
      var textProp = StringProp(e.text);
      return SmdEntryData(
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

  List<SmdEntry> toEntries() 
    => List.generate(length, (i) => SmdEntry(this[i].id.value, i * 10, this[i].text.value));

  @override
  void onRowAdd() {
    var idProp = StringProp("ID");
    var textProp = StringProp("Text");
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
      var idProp = StringProp(values[0]!);
      var textProp = StringProp(values[1]!);
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
