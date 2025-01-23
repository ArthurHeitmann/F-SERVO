
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../main.dart';
import '../../stateManagement/Property.dart';
import '../../stateManagement/events/statusInfo.dart';
import '../../stateManagement/listNotifier.dart';
import '../../stateManagement/openFiles/openFilesManager.dart';
import '../../stateManagement/preferencesData.dart';
import '../../utils/batchLocalization/BatchLocalizationData.dart';
import '../../utils/batchLocalization/BatchLocalizationExporter.dart';
import '../../utils/batchLocalization/LocalizationExtractor.dart';
import '../../utils/utils.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/confirmDialog.dart';
import '../propEditors/UnderlinePropTextField.dart';
import '../propEditors/boolPropCheckbox.dart';
import '../propEditors/propEditorFactory.dart';
import '../propEditors/propTextField.dart';
import '../theme/customTheme.dart';

class BatchLocalizationTool extends StatefulWidget {
  const BatchLocalizationTool({super.key});

  @override
  State<BatchLocalizationTool> createState() => _BatchLocalizationToolState();
}

class _BatchLocalizationToolState extends State<BatchLocalizationTool> {
  final workingDirectory = StringProp("", fileId: null);
  bool extractMode = true;
  final useJson = BoolProp(false, fileId: null);
  bool hasGuessedJsonMode = false;
  // extract
  bool datsAlreadyExtracted = false;
  BatchLocalizationLanguage language = BatchLocalizationLanguage.fr;
  final reextractDats = BoolProp(false, fileId: null);
  final searchPaths = ValueListNotifier<StringProp>([], fileId: null);
  final extractMcd = BoolProp(true, fileId: null);
  final extractTmd = BoolProp(true, fileId: null);
  final extractSmd = BoolProp(true, fileId: null);
  final extractRb = BoolProp(true, fileId: null);
  final extractHap = BoolProp(true, fileId: null);
  BatchLocExtractionProgress? extractionProgress;
  // repack
  final repackPath = StringProp("", fileId: null);
  BatchLocExportProgress? exportProgress;

  @override
  void initState() {
    super.initState();
    var prefs = PreferencesData();
    repackPath.value = prefs.dataExportPath?.value ?? "";
    searchPaths.add(StringProp("", fileId: null));
    workingDirectory.addListener(_onWorkingDirectoryChange);
  }

  @override
  void dispose() {
    workingDirectory.dispose();
    reextractDats.dispose();
    searchPaths.dispose();
    extractMcd.dispose();
    extractTmd.dispose();
    extractSmd.dispose();
    extractRb.dispose();
    extractHap.dispose();
    repackPath.dispose();
    extractionProgress?.dispose();
    exportProgress?.dispose();
    super.dispose();
  }

  void _onWorkingDirectoryChange() {
    _guessJsonMode();
    _checkIfAlreadyExtracted();
  }

  void _guessJsonMode() async {
    if (!await Directory(workingDirectory.value).exists()) {
      hasGuessedJsonMode = false;
      return;
    }
    if (hasGuessedJsonMode)
      return;
    var txtPath = join(workingDirectory.value, "localization.txt");
    var jsonPath = join(workingDirectory.value, "localization.json");
    var txtExists = await File(txtPath).exists();
    var jsonExists = await File(jsonPath).exists();
    switch ((txtExists, jsonExists)) {
      case (true, false):
        useJson.value = false;
        break;
      case (false, true):
        useJson.value = true;
        break;
      case (false, false):
        break;
      case (true, true):
        var txtStat = await File(txtPath).stat();
        var jsonStat = await File(jsonPath).stat();
        useJson.value = jsonStat.modified.isAfter(txtStat.modified);
        break;
    }
    if (txtExists || jsonExists)
      hasGuessedJsonMode = true;
  }

  void _checkIfAlreadyExtracted() async {
    bool newDatsAlreadyExtracted;
    var datsDir = join(workingDirectory.value, "dat", datSubExtractDir);
    if (!await Directory(datsDir).exists()) {
      newDatsAlreadyExtracted = false;
    }
    else {
      var extractedFiles = await Directory(datsDir).list().take(2).length;
      newDatsAlreadyExtracted = extractedFiles > 0;
    }
    if (newDatsAlreadyExtracted != datsAlreadyExtracted) {
      datsAlreadyExtracted = newDatsAlreadyExtracted;
      setState(() {});
    }
  }

  void _extract() async {
    var workDirValid = await Directory(workingDirectory.value).exists();
    var searchPathsValid = 
      (await Future.wait(searchPaths.map((e) => Directory(e.value).exists())))
      .every((e) => e);
    if (!workDirValid || !searchPathsValid) {
      showToast("Working directory or search path are invalid");
      return;
    }
    var saveName = useJson.value ? "localization.json" : "localization.txt";
    var savePath = join(workingDirectory.value, saveName);
    if (await File(savePath).exists()) {
      var answer = await confirmDialog(
        getGlobalContext(),
        title: "Overwrite $saveName?",
        body: "All data in $saveName will be lost."
      );
      if (answer != true)
        return;
    }

    extractionProgress?.reset();
    extractionProgress ??= BatchLocExtractionProgress();
    extractionProgress!.isRunning = true;
    setState(() {});
    try {
      await extractLocalizationFiles(
        workDir: workingDirectory.value,
        searchPaths: searchPaths.map((e) => e.value).toList(),
        savePath: savePath,
        language: language,
        reextractDats: reextractDats.value,
        extractMcd: extractMcd.value,
        extractTmd: extractTmd.value,
        extractSmd: extractSmd.value,
        extractRb: extractRb.value,
        extractHap: extractHap.value,
        progress: extractionProgress!,
      );
    } on Exception catch (e, st) {
      messageLog.add("Error during extraction: \n$e\n$st");
      extractionProgress?.error ??= "An error occurred during extraction";
    }
    extractionProgress!.isRunning = false;
    setState(() {});
  }

  Future<void> _repack() async {
    var workDirValid = await Directory(workingDirectory.value).exists();
    var repackDirValid = await Directory(repackPath.value).exists();
    if (!workDirValid || !repackDirValid) {
      showToast("Working directory or repack directory are invalid");
      return;
    }
    var saveName = useJson.value ? "localization.json" : "localization.txt";
    var savePath = join(workingDirectory.value, saveName);
    if (!await File(savePath).exists()) {
      showToast("$saveName not found in working directory");
      return;
    }

    exportProgress?.reset();
    exportProgress ??= BatchLocExportProgress();
    exportProgress!.isRunning = true;
    setState(() {});
    try {
      await exportBatchLocalization(
        workingDirectory: workingDirectory.value,
        localizationFile: savePath,
        exportFolder: repackPath.value,
        progress: exportProgress!,
      );
    } on Exception catch (e, st) {
      messageLog.add("$e\n$st");
      messageLog.add("Error during export");
    }
    exportProgress!.isRunning = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _makeTabBar(context),
        _makeCommonSettings(),
        if (extractMode)
          _makeExtractTab()
        else
          _makeRepackTab(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _makeTabBar(BuildContext context) {
    ButtonStyle getStyle(bool isActive) {
      return ButtonStyle(
        backgroundColor: isActive
          ? WidgetStateProperty.all(getTheme(context).textColor!.withOpacity(0.1))
          : WidgetStateProperty.all(Colors.transparent),
        foregroundColor: isActive
          ? WidgetStateProperty.all(getTheme(context).textColor)
          : WidgetStateProperty.all(getTheme(context).textColor!.withOpacity(0.5))
      );
    }
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => extractMode = true),
              style: getStyle(extractMode),
              child: const Text("Extract"),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () => setState(() => extractMode = false),
              style: getStyle(!extractMode),
              child: const Text("Repack"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _makeCommonSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _makeFolderSelector("Working directory", workingDirectory),
        ],
      ),
    );
  }

  Widget _makeExtractTab() {
    var progress = extractionProgress;
    return Padding(
      key: Key("extractTab"),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _makeSearchPaths(),
          _makeLanguageSelector(),
          Text("Extracted file types:"),
          _makeCheckBox("mcd", extractMcd),
          _makeCheckBox("tmd", extractTmd),
          _makeCheckBox("smd", extractSmd),
          _makeCheckBox("rb", extractRb),
          _makeCheckBox("hap", extractHap),
          _makeCheckBox("Use JSON format", useJson),
          if (datsAlreadyExtracted)
            _makeCheckBox("Re-extract DATs", reextractDats),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: progress?.isRunning != true ? _extract : null,
            child: Align(
              alignment: Alignment.center,
              child: const Text("Extract"),
            ),
          ),
          if (progress != null)
            ChangeNotifierBuilder(
              notifier: progress,
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "File ${progress.processedFiles} / ${progress.totalFiles}: ${progress.currentFile ?? ""}",
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.processedFiles / (max(progress.totalFiles, 1)),
                    backgroundColor: Colors.transparent,
                  ),
                  if (progress.error != null)
                    Text(progress.error!),
                ],
              )
            )
        ],
      ),
    );
  }

  Widget _makeRepackTab() {
    var progress = exportProgress;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        key: Key("repackTab"),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _makeFolderSelector("Repack directory", repackPath),
          _makeCheckBox("Use JSON format", useJson),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => areasManager.openFile("fontSettings"),
              child: Text("Open MCD font settings")
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: exportProgress?.isRunning != true ? _repack : null,
            child: Align(
              alignment: Alignment.center,
              child: const Text("Repack")
            ),
          ),
          if (progress != null)
            ChangeNotifierBuilder(
              notifier: progress,
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text("Step ${progress.step} / ${progress.totalSteps}: ${progress.stepName}", overflow: TextOverflow.ellipsis,),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.step / (max(progress.totalSteps, 1)),
                    backgroundColor: Colors.transparent,
                  ),
                  const SizedBox(height: 4),
                  if (progress.step == 2 && progress.totalFiles == 0)
                    const Text("No changed files")
                  else
                    Text("File ${progress.file} / ${progress.totalFiles}: ${progress.currentFile ?? ""}", overflow: TextOverflow.ellipsis,),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.totalFiles != 0 ? progress.file / progress.totalFiles : 1,
                    backgroundColor: Colors.transparent,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _makeLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Flexible(
            child: const Text("Language to edit: ", overflow: TextOverflow.ellipsis),
          ),
          PopupMenuButton<BatchLocalizationLanguage>(
            initialValue: language,
            onSelected: (lang) {
              setState(() => language = lang);
            },
            itemBuilder: (context) => _langNames.entries.map((e) => PopupMenuItem(
              value: e.key,
              height: 25,
              child: Text(e.value),
            )).toList(),
            position: PopupMenuPosition.under,
            // constraints: BoxConstraints.tightFor(width: 60),
            popUpAnimationStyle: AnimationStyle(duration: Duration.zero),
            tooltip: "",
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                Text(
                  _langNames[language]!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _makeSearchPaths() {
    return ChangeNotifierBuilder(
      notifier: searchPaths,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < searchPaths.length; i++)
            Row(
              children: [
                Expanded(
                  child: _makeFolderSelector("Search path", searchPaths[i]),
                ),
                if (i > 0)
                  _makeIconButton(
                    onPressed: () => searchPaths.removeAt(i),
                    child: const Icon(Icons.close),
                  ),
              ],
            ),
          _makeIconButton(
            onPressed: () => searchPaths.add(StringProp("", fileId: null)),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _makeFolderSelector(String label, StringProp prop) {
    return Row(
      children: [
        Expanded(
          child: makePropEditor<UnderlinePropTextField>(prop, PropTFOptions(hintText: label))
        ),
        _makeIconButton(
          onPressed: () async {
            var result = await FilePicker.platform.getDirectoryPath(
              dialogTitle: "Select $label",
            );
            if (result == null)
              return;
            prop.value = result;
          },
          child: const Icon(Icons.folder),
        ),
      ],
    );
  }

  Widget _makeCheckBox(String label, BoolProp prop) {
    return Row(
      children: [
        BoolPropCheckbox(prop: prop),
        Flexible(
          child: GestureDetector(
            onTap: () => prop.value = !prop.value,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  Widget _makeIconButton({required VoidCallback onPressed, required Widget child}) {
    return IconButton(
      onPressed: onPressed,
      splashRadius: 20,
      icon: child,
    );
  }
}

const _langNames = {
  BatchLocalizationLanguage.us: "English",
  BatchLocalizationLanguage.fr: "French",
  BatchLocalizationLanguage.de: "German",
  BatchLocalizationLanguage.it: "Italian",
  BatchLocalizationLanguage.jp: "Japanese",
  BatchLocalizationLanguage.es: "Spanish",
};
