
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

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
    fileName: "${basenameWithoutExtension(tableConfig.name)}.json",
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
    fileName: "${basenameWithoutExtension(tableConfig.name)}.csv",
    allowedExtensions: ["csv"],
    type: FileType.custom,
  );
  if (savePath == null)
    return;
  
  var stringsTable = _tablePropsToStrings(tableConfig);
  const csvConverter = ListToCsvConverter(eol: "\n", convertNullTo: "\x00");
  var csv = csvConverter.convert([
    tableConfig.columnNames,
    ...stringsTable,
  ]);
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
    const csvConverter = CsvToListConverter(eol: "\n", convertEmptyTo: "");
    var table = csvConverter.convert(csv)
      .map((row) => row.cast<String?>().map((cell) => cell == "\x00" ? null : cell).toList())
      .toList();
    for (int i = 0; i < table.length; i++) {
      tableConfig.updateRowWith(i, table[i]);
    }
  } catch (e) {
    print(e);
    showToast("Failed to load table from CSV");
  }
}
