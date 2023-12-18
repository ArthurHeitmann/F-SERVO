
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../stateManagement/Property.dart';
import '../../utils/utils.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../propEditors/boolPropCheckbox.dart';
import '../theme/customTheme.dart';
import 'ExtractFilesService.dart';

class ExtractFilesTool extends StatefulWidget {
  const ExtractFilesTool({super.key});

  @override
  State<ExtractFilesTool> createState() => _ExtractFilesToolState();
}

class _ExtractFilesToolState extends State<ExtractFilesTool> {
  List<File>? selectedFiles;
  Directory? selectedDirectory;
  Directory? cpkExtractDirectory;
  bool hasCpkFilesSelected = false;
  bool get hasFilesSelected => selectedFiles != null && selectedFiles!.isNotEmpty || selectedDirectory != null;
  BoolProp recursive = BoolProp(true, fileId: null);
  BoolProp extractCpk = BoolProp(true, fileId: null);
  BoolProp extractDat = BoolProp(true, fileId: null);
  BoolProp extractWta = BoolProp(true, fileId: null);
  BoolProp extractBnk = BoolProp(true, fileId: null);
  BoolProp convertScripts = BoolProp(true, fileId: null);
  BoolProp convertBxm = BoolProp(true, fileId: null);
  List<BoolProp> get props => [recursive, extractCpk, extractDat, extractWta, extractBnk, convertScripts, convertBxm];
  List<(String, BoolProp)> get namedOptionProps => [
    ("Extract CPK", extractCpk),
    ("Extract DAT", extractDat),
    ("Extract Textures", extractWta),
    ("Extract Audio", extractBnk),
    ("Convert Scripts", convertScripts),
    ("Convert BXM", convertBxm),
  ];

  FileExtractorService? service;
  bool isStarting = false;
  bool isStopped = false;

  @override
  void dispose() {
    for (var prop in props)
      prop.dispose();
    service?.stop();
    service?.dispose();
    super.dispose();
  }

  void selectFiles() async {
    var files = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (files == null || files.files.isEmpty)
      return;
    selectedFiles = files.files.map((e) => File(e.path!)).toList();
    selectedDirectory = null;
    hasCpkFilesSelected = selectedFiles!.any((e) => e.path.endsWith(".cpk"));
    setState(() {});
  }

  void selectDirectory() async {
    var directory = await FilePicker.platform.getDirectoryPath();
    if (directory == null)
      return;
    selectedFiles = null;
    selectedDirectory = Directory(directory);
    searchSelectedDirectoryForCpkFiles();
    setState(() {});
  }

  void selectExtractDirectory() async {
    var directory = await FilePicker.platform.getDirectoryPath();
    if (directory == null)
      return;
    cpkExtractDirectory = Directory(directory);
    setState(() {});
  }

  void toggleRecursive() {
    recursive.value = !recursive.value;
    searchSelectedDirectoryForCpkFiles();
    setState(() {});
  }

  void searchSelectedDirectoryForCpkFiles() async {
    if (selectedDirectory == null)
      return;
    await for (var file in selectedDirectory!.list(recursive: recursive.value)) {
      if (file is! File)
        continue;
      if (!file.path.endsWith(".cpk"))
        continue;
      print("Found CPK file: ${file.path}");
      hasCpkFilesSelected = true;
      setState(() {});
      return;
    }
    print("No CPK files found");
    hasCpkFilesSelected = false;
    setState(() {});
  }

  void extractFiles() async {
    if (isStarting)
      return;
    if (selectedFiles == null && selectedDirectory == null)
      return;
    if (selectedFiles != null && selectedDirectory != null)
      return;
    isStarting = true;
    isStopped = false;
    await service?.stop();
    service?.dispose();
    service = FileExtractorService();
    service!.extract(ExtractFilesParam(
      selectedFiles?.map((e) => e.path).toList(),
      selectedDirectory?.path,
      recursive.value,
      cpkExtractDirectory?.path,
      extractCpk.value,
      extractDat.value,
      extractWta.value,
      extractBnk.value,
      convertScripts.value,
      convertBxm.value,
    ));
    service!.isRunning.addListener(() {
      if (!service!.isRunning.value)
        isStopped = true;
      setState(() {});
    });
    isStarting = false;
    setState(() {});
  }

  void stopExtractingFiles() async {
    if (isStopped)
      return;
    isStopped = true;
    await service?.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierBuilder(
      notifiers: props,
      builder: (context) {
        List<Widget> top;
        if (!hasFilesSelected) {
          top = [
            Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints.tightFor(height: 50),
                    child: TextButton(
                      onPressed: selectFiles,
                      child: const Text("Select files to extract", textAlign: TextAlign.center),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints.tightFor(height: 50),
                    child: TextButton(
                      onPressed: selectDirectory,
                      child: const Text("Select folder to search", textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            )
          ];
        }
        else if (selectedFiles != null) {
          top = [
            if (selectedFiles!.length > 1)
              Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text("Selected ${pluralStr(selectedFiles!.length, "files")}")
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                      onPressed: () => setState(() => selectedFiles = null),
                      icon: Icon(Icons.clear, color: getTheme(context).titleBarButtonCloseColor, size: 20),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 40, height: 35)
                  ),
                ],
              ),
            for (var file in selectedFiles!)
              Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(basename(file.path), overflow: TextOverflow.ellipsis, textScaler: const TextScaler.linear(0.9),)
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => setState(() => selectedFiles!.remove(file)),
                    icon: Icon(Icons.clear, color: getTheme(context).titleBarButtonCloseColor, size: 20),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 40, height: 35)
                  ),
                ],
              )
          ];
        }
        else {
          top = [
            Row(
              children: [
                const SizedBox(width: 10),
                const Text("Search folder: ", style: TextStyle(fontWeight: FontWeight.bold),),
                Expanded(
                  child: Text(selectedDirectory!.path, overflow: TextOverflow.ellipsis)
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => setState(() => selectedDirectory = null),
                  icon: Icon(Icons.clear, color: getTheme(context).titleBarButtonCloseColor),
                  splashRadius: 16
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () => setState(() => recursive.value = !recursive.value),
                    child: const Text("Search all subfolders", overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 10),
                BoolPropCheckbox(prop: recursive),
                const SizedBox(width: 40),
              ],
            ),
          ];
        }

        return Column(
          children: [
            ...top,
            Row(
              children: [
                if (cpkExtractDirectory == null && hasCpkFilesSelected)
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints.tightFor(height: 50),
                      child: TextButton(
                        onPressed: selectExtractDirectory,
                        child: const Text("Select Custom CPK Extract Directory"),
                      ),
                    ),
                  )
                else if(cpkExtractDirectory != null) ...[
                  const SizedBox(width: 10),
                  const Text("Extract folder: ", style: TextStyle(fontWeight: FontWeight.bold),),
                  Expanded(
                    child: Text(cpkExtractDirectory!.path, overflow: TextOverflow.ellipsis)
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => setState(() => cpkExtractDirectory = null),
                    icon: Icon(Icons.clear, color: getTheme(context).titleBarButtonCloseColor),
                    splashRadius: 16
                  ),
                ],
              ],
            ),
            for (var (name, prop) in namedOptionProps)
              Row(
                children: [
                  const SizedBox(width: 10),
                  BoolPropCheckbox(prop: prop),
                  const SizedBox(width: 10),
                  Flexible(
                    child: GestureDetector(
                      onTap: () => setState(() => prop.value = !prop.value),
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints.tightFor(height: 50),
              child: service == null || isStopped
                ? TextButton(
                  onPressed: hasFilesSelected || selectedDirectory != null ? extractFiles : null,
                  child: const Text(
                    "Extract Files",
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(1.2),
                  ),
                )
                : TextButton(
                  onPressed: isStopped ? null : stopExtractingFiles,
                  child: const Text(
                    "Cancel",
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(1.2),
                  ),
                ),
            ),
            if (service != null) ...[
              Padding(
                key: Key(service!.uuid),
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: ChangeNotifierBuilder(
                        notifiers: [service!.processedFiles, service!.remainingFiles],
                        builder: (context) => Text(
                          "Processed: ${service!.processedFiles.value}    Pending: ${service!.remainingFiles.value}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    ChangeNotifierBuilder(
                      notifier: service!.isRunning,
                      builder: (context) => service!.isRunning.value
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: getTheme(context).textColor,)
                        )
                        : const Icon(Icons.check)
                    ),
                  ],
                ),
              )
            ]
          ],
        );
      }
    );
  }
}
