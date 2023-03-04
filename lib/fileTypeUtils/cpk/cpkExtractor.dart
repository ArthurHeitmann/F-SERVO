
import 'dart:io';

import 'package:path/path.dart';

import '../../main.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/preferencesData.dart';
import '../../widgets/misc/fileSelectionDialog.dart';
import '../utils/ByteDataWrapper.dart';
import 'cpk.dart';

Future<List<String>> extractCpk(String cpkPath, String extractDir) async {
  var cpk = Cpk.read(await ByteDataWrapper.fromFile(cpkPath));
  bool logProgress = cpk.files.length > 250;
  int tenPercentIncrement = (cpk.files.length / 10).round();
  for (int i = 0; i < cpk.files.length; i++) {
    var file = cpk.files[i];
    print("Extracting ${file.name}");
    var folder = join(extractDir, file.path);
    var filePath = join(folder, file.name);
    await Directory(folder).create(recursive: true);
    await File(filePath).writeAsBytes(file.getData());
    if (logProgress && i % tenPercentIncrement == 0) {
      var percentProgress = ((i + 1) / cpk.files.length * 100).toStringAsFixed(1);
      messageLog.add("Extracted $percentProgress% of files (${(i+1)}/${cpk.files.length})");
    }
  }
  if (logProgress)
    messageLog.add("Extracted 100% of files (${cpk.files.length}/${cpk.files.length})");
  return cpk.files
    .map((file) => join(extractDir, file.path, file.name))
    .toList();
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
  
  var extractDir = join(extractDirSel, basename(cpkPath));
  if (await File(extractDir).exists())
    extractDir += "_unpacked";
  try {
    isLoadingStatus.pushIsLoading();
    await extractCpk(cpkPath, extractDir);
  } finally {
    isLoadingStatus.popIsLoading();
  }
  return extractDir;
}
