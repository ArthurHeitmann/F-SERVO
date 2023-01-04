
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../../../utils/utils.dart';
import 'tableEditor.dart';

List<List<String?>> _tablePropsToStrings(CustomTableConfig tableConfig) {
  List<RowConfig> rows = List.generate(
    tableConfig.rowCount.value as int,
    (index) => tableConfig.rowPropsGenerator(index),
  );
  return rows.map((row) {
    return List.generate(
      row.cells.length,
      (index) => row.cells[index]?.toExportString()
    );
  }).toList();
}

Future<void> saveTableAsJson(CustomTableConfig tableConfig) async {
  var savePath = await FilePicker.platform.saveFile(
    dialogTitle: "Save Table As JSON",
    allowedExtensions: ["json"],
    type: FileType.custom,
  );
  if (savePath == null)
    return;
  
  var stringsTable = _tablePropsToStrings(tableConfig);
  var json = const JsonEncoder.withIndent("\t").convert(
    {
      "columnNames": tableConfig.columnNames,
      "table": stringsTable,
    },
  );
  var saveFile = File(savePath);
  await saveFile.writeAsString(json);
}

Future<void> saveTableAsCsv(CustomTableConfig tableConfig) async {
  var savePath = await FilePicker.platform.saveFile(
    dialogTitle: "Export Table As CSV",
    allowedExtensions: ["csv"],
    type: FileType.custom,
  );
  if (savePath == null)
    return;
  
  var stringsTable = _tablePropsToStrings(tableConfig);
  var csv = "${tableConfig.columnNames.join(",")}\n";
  csv += stringsTable.map((row) =>
    row.map((cell) => cell ?? "\x00").join(",")
  ).join("\n");
  var saveFile = File(savePath);
  await saveFile.writeAsString(csv);
}

Future<void> loadTableFromJson(CustomTableConfig tableConfig) async {
  var loadPath = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ["json"],
  );
  if (loadPath == null)
    return;
  
  var loadFile = File(loadPath.files.single.path!);
  try {
    var json = await loadFile.readAsString();
    var decoded = jsonDecode(json);
    var table = (decoded["table"] as List)
      .map((row) => (row as List).cast<String?>())
      .toList();
    for (int i = 0; i < table.length; i++) {
      tableConfig.updateRowWith(i, table[i]);
    }
  } catch (e) {
    print(e);
    showToast("Failed to load table from JSON");
  }
}

Future<void> loadTableFromCsv(CustomTableConfig tableConfig) async {
  var loadPath = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ["csv"],
  );
  if (loadPath == null)
    return;
  
  var loadFile = File(loadPath.files.single.path!);
  try {
    var csv = await loadFile.readAsString();
    var lines = csv.split("\n");
    var table = lines
      .sublist(1)
      .map((line) => line.split(",")
        .map((cell) => cell == "\x00" ? null : cell)
        .toList()
      )
      .toList();
    for (int i = 0; i < table.length; i++) {
      tableConfig.updateRowWith(i, table[i]);
    }
  } catch (e) {
    print(e);
    showToast("Failed to load table from CSV");
  }
}
