
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:path/path.dart';

import '../../../../fileSystem/FileSystem.dart';
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
  var stringsTable = _tablePropsToStrings(tableConfig);
  var json = const JsonEncoder.withIndent("\t").convert(
    {
      "columnNames": tableConfig.columnNames,
      "table": stringsTable,
    },
  );
  await FS.i.saveFile(
    text: json,
    dialogTitle: "Save Table As JSON",
    fileName: "${basenameWithoutExtension(tableConfig.name)}.json",
    allowedExtensions: ["json"],
  );
}

Future<void> saveTableAsCsv(CustomTableConfig tableConfig) async {
  var stringsTable = _tablePropsToStrings(tableConfig);
  const csvConverter = ListToCsvConverter(eol: "\n", convertNullTo: "\x00");
  var csv = csvConverter.convert([
    tableConfig.columnNames,
    ...stringsTable,
  ]);
  await FS.i.saveFile(
    text: csv,
    dialogTitle: "Export Table As CSV",
    fileName: "${basenameWithoutExtension(tableConfig.name)}.csv",
    allowedExtensions: ["csv"],
  );
}

Future<void> loadTableFromJson(CustomTableConfig tableConfig) async {
  var loadPath = await FS.i.selectFiles(
    allowedExtensions: ["json"],
  );
  if (loadPath.isEmpty)
    return;
  
  try {
    var loadFile = loadPath.single;
    var json = await FS.i.readAsString(loadFile);
    var decoded = jsonDecode(json);
    var table = (decoded["table"] as List)
      .map((row) => (row as List).cast<String?>())
      .toList();
    for (int i = 0; i < table.length; i++) {
      tableConfig.updateRowWith(i, table[i]);
    }
  } catch (e, s) {
    print("$e\n$s");
    showToast("Failed to load table from JSON");
  }
}

Future<void> loadTableFromCsv(CustomTableConfig tableConfig) async {
  var loadPath = await FS.i.selectFiles(
    allowedExtensions: ["csv"],
  );
  if (loadPath.isEmpty)
    return;
  
  try {
    var loadFile = loadPath.single;
    var csv = await FS.i.readAsString(loadFile);
    const csvConverter = CsvToListConverter(eol: "\n", convertEmptyTo: "");
    var table = csvConverter.convert(csv)
      .map((row) => row.cast<String?>().map((cell) => cell == "\x00" ? null : cell).toList())
      .toList();
    for (int i = 0; i < table.length; i++) {
      tableConfig.updateRowWith(i, table[i]);
    }
  } catch (e, s) {
    print("$e\n$s");
    showToast("Failed to load table from CSV");
  }
}
