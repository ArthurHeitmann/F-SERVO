
import 'dart:io';

import 'package:path/path.dart';

import '../../main.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/preferencesData.dart';
import '../../widgets/misc/fileSelectionDialog.dart';
import '../utils/ByteDataWrapperRA.dart';
import 'cpk.dart';

Future<List<String>> extractCpk(String cpkPath, { String? extractDir, bool logProgress = true }) async {
  var bytes = await ByteDataWrapperRA.fromFile(cpkPath);
  try {
    var cpk = await Cpk.read(bytes);
    logProgress = logProgress && cpk.files.length > 250;
    int tenPercentIncrement = (cpk.files.length / 10).round();
    extractDir ??= dirname(cpkPath);
    List<String> filePaths = [];
    for (int i = 0; i < cpk.files.length; i++) {
      var file = cpk.files[i];
      print("Extracting ${file.name}");
      var folder = join(extractDir, basename(cpkPath));
      if (await File(folder).exists())
        folder += "_extracted";
      folder = join(folder, file.path);
      var filePath = join(folder, file.name);
      filePaths.add(filePath);
      await Directory(folder).create(recursive: true);
      await File(filePath).writeAsBytes(await file.readData(bytes));
      if (logProgress && i % tenPercentIncrement == 0) {
        var percentProgress = ((i) / cpk.files.length * 100).toStringAsFixed(1);
        messageLog.add("Extracted $percentProgress% of files (${(i + 1)}/${cpk.files.length})");
      }
    }
    if (logProgress)
      messageLog.add("Extracted 100% of files (${cpk.files.length}/${cpk.files.length})");
    return filePaths;
  } finally {
    await bytes.close();
  }
}

Future<String?> extractCpkWithPrompt(String cpkPath) async {
  var prefs = PreferencesData();
  var lastExtractDir = prefs.lastCpkExtractDir;
  bool useLastExtractDir = lastExtractDir != null && lastExtractDir.value.isNotEmpty && await Directory(lastExtractDir.value).exists();
  var extractDirSel = await fileSelectionDialog(
    getGlobalContext(),
    selectionType: SelectionType.folder,
    title: "Select folder to extract to",
    initialDirectory: useLastExtractDir ? lastExtractDir.value : null,
  );
  if (extractDirSel == null)
    return null;
  prefs.lastCpkExtractDir!.value = extractDirSel;

  try {
    isLoadingStatus.pushIsLoading();
    await extractCpk(cpkPath, extractDir: extractDirSel);
  } finally {
    isLoadingStatus.popIsLoading();
  }
  return extractDirSel;
}
