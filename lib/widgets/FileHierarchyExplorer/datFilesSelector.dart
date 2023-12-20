
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../main.dart';
import '../../stateManagement/Property.dart';
import '../../stateManagement/hierarchy/types/DatHierarchyEntry.dart';
import '../../utils/utils.dart';
import '../misc/ChangeNotifierWidget.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../theme/customTheme.dart';


void showDatSelectorPopup(DatHierarchyEntry datEntry) {
  showDialog(
    context: getGlobalContext(),
    builder: (context) => Dialog(
      backgroundColor: getTheme(context).sidebarBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        constraints: const BoxConstraints(maxWidth: 600),
        child: _DatSelectorWidget(datEntry: datEntry),
      ),
    ),
  );
}

class _DatSelectorWidget extends StatefulWidget {
  final DatHierarchyEntry datEntry;

  const _DatSelectorWidget({super.key, required this.datEntry});

  @override
  State<_DatSelectorWidget> createState() => _DatSelectorWidgetState();
}

class _DatSelectorWidgetState extends State<_DatSelectorWidget> {
  final controller = ScrollController();
  List<(String, BoolProp)>? files;
  bool? multiSelectToggleType;

  @override
  void initState() {
    super.initState();
    getFiles();
  }

  @override
  void dispose() {
    if (files != null) {
      for (var (_, prop) in files!)
        prop.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (files == null)
      return const Center(child: CircularProgressIndicator());
    var windowHeight = MediaQuery.of(context).size.height;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Change packed files", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text("Select which files to include in the DAT file. This displays all files in the extracted folder."),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: min(windowHeight - 300, windowHeight * 0.8)),
          child: SmoothSingleChildScrollView(
            controller: controller,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var (path, prop) in files!)
                  Listener(
                    onPointerDown: (details) {
                      if (details.kind != PointerDeviceKind.mouse)
                        return;
                      multiSelectToggleType = !prop.value;
                      prop.value = multiSelectToggleType!;
                    },
                    onPointerUp: (details) {
                      multiSelectToggleType = null;
                    },
                    child: MouseRegion(
                      onEnter: (details) {
                        if (multiSelectToggleType == null)
                          return;
                        prop.value = multiSelectToggleType!;
                      },
                      child: Row(
                        children: [
                          ChangeNotifierBuilder(
                            notifier: prop,
                            builder: (context) {
                              return Checkbox(
                                value: prop.value,
                                onChanged: (value) {},
                              );
                            }
                          ),
                          Expanded(
                            child: Text(basename(path))
                          ),
                        ],
                      )
                    )
                  ),
              ],
            )
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => save(export: false).then((value) => Navigator.of(context).pop()),
              child: const Text("Save"),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => save(export: true).then((value) => Navigator.of(context).pop()),
              child: const Text("Save and export"),
            ),
          ],
        )
      ],
    );
  }

  Future<void> getFiles() async {
    var datFiles = await getDatFileList(widget.datEntry.extractedPath);
    var folderItems = await Directory(widget.datEntry.extractedPath).list().toList();
    files = folderItems
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => extension(path).length <= 4)
        .map((path) => (path, BoolProp(datFiles.contains(path), fileId: null)))
        .toList();
    setState(() {});
  }

  Future<void> save({ required bool export }) async {
    var datInfoPath = join(widget.datEntry.extractedPath, "dat_info.json");
    Map datInfo;
    if (await File(datInfoPath).exists()) {
      datInfo = jsonDecode(await File(datInfoPath).readAsString());
    } else {
      datInfo = {
        "version": 1,
        "files": [],
        "basename": basenameWithoutExtension(widget.datEntry.path),
        "ext": extension(widget.datEntry.path),
      };
    }
    var datFilePaths = files!
      .where((file) => file.$2.value)
      .map((file) => file.$1)
      .toList();
    datFilePaths.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    var datFileNames = datFilePaths
      .map((file) => basename(file))
      .toList();
    datInfo["files"] = datFileNames;
    await File(datInfoPath).writeAsString(const JsonEncoder.withIndent("\t").convert(datInfo));
    if (export)
      await widget.datEntry.repackDatAction();
    await widget.datEntry.loadChildren(datFilePaths);
  }
}
