
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/listNotifier.dart';
import '../../../stateManagement/openFiles/types/WtaWtpData.dart';
import '../../../utils/utils.dart';
import '../../theme/customTheme.dart';
import 'genericTable/tableEditor.dart';

class WtaWtpEditor extends StatefulWidget {
  final WtaWtpData file;

  const WtaWtpEditor({ super.key, required this.file });

  @override
  State<WtaWtpEditor> createState() => _WtaWtpEditorState();
}

class _TexturesTableConfig with CustomTableConfig {
  final WtaWtpData file;
  final WtaWtpTextures texData;
  final ListNotifier<WtaTextureEntry> textures;

  _TexturesTableConfig(this.file, String name, this.texData)
    : textures = texData.textures {
    this.name = name;
    columnNames = [
      "ID", "Path", "", "",
      if (texData.hasAnySimpleModeFlags)
        "Is Albedo?",
      if (!texData.useFlagsSimpleMode)
        "Flags",
    ];
    columnFlex = [
      2, 9, 1, 1,
      if (texData.hasAnySimpleModeFlags)
        2,
      if (!texData.useFlagsSimpleMode)
        2,
    ];
    rowCount = NumberProp(textures.length, true, fileId: null);
    textures.addListener(() => rowCount.value = textures.length);
  }

  @override
  RowConfig rowPropsGenerator(int index) {
    return RowConfig(
      key: Key(textures[index].uuid),
      cells: [
        PropCellConfig(prop: textures[index].id),
        PropCellConfig(prop: textures[index].path),
        CustomWidgetCellConfig(IconButton(
          icon: const Icon(Icons.folder, size: 20),
          onPressed: () => _selectTexture(index),
        )),
        CustomWidgetCellConfig(IconButton(
          icon: const Icon(Icons.delete, size: 20),
          onPressed: () => onRowRemove(index),
        )),
        if (texData.hasAnySimpleModeFlags)
          PropCellConfig(prop: textures[index].isAlbedo!),
        if (!texData.useFlagsSimpleMode)
          PropCellConfig(prop: textures[index].flag!),
      ]
    );
  }

  Future<void> _selectTexture(int index) async {
    var paths = await FilePicker.platform.pickFiles(
      dialogTitle: "Select DDS",
      type: FileType.custom,
      allowedExtensions: ["dds"],
    );
    if (paths == null)
      return;
    var path = paths.files.first.path!;
    textures[index].path.updateWith(path);
  }

  @override
  void updateRowWith(int index, List<String?> values) {
    showToast("Not supported");
    throw UnimplementedError();
  }

  @override
  void onRowAdd() {
    textures.add(WtaTextureEntry(
      texData.file,
      HexProp(randomId(), fileId: file.uuid),
      StringProp("", fileId: file.uuid),
      isAlbedo: texData.useFlagsSimpleMode ? BoolProp(false, fileId: file.uuid) : null,
      flag: texData.useFlagsSimpleMode ? null : HexProp(textures.isNotEmpty ? textures.last.flag!.value : 0, fileId: file.uuid),
    ));
    file.onUndoableEvent();
  }

  @override
  void onRowRemove(int index) {
    textures.removeAt(index);
    file.onUndoableEvent();
  }

  Future<void> patchImportFolder() async {
    var folderSel = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select folder with DDS files",
    );
    if (folderSel == null)
      return;
    var allDdsFiles = await Directory(folderSel).list()
      .where((e) => e is File && e.path.endsWith(".dds"))
      .map((e) => e.path)
      .toList();
    List<String> ddsFilesOrdered = List.generate(allDdsFiles.length, (index) => "");
    for (var dds in allDdsFiles) {
      var indexRes = RegExp(r"^\d+").firstMatch(basename(dds));
      if (indexRes == null)
        continue;
      int index = int.parse(indexRes.group(0)!);
      if (index >= ddsFilesOrdered.length) {
        showToast("Index $index is out of range (${ddsFilesOrdered.length})");
        return;
      }
      ddsFilesOrdered[index] = dds;
    }
    if (ddsFilesOrdered.any((e) => e.isEmpty)) {
      showToast("Some DDS files are missing");
      return;
    }
    textures.addAll(ddsFilesOrdered.map((file) => WtaTextureEntry(
      texData.file,
      HexProp(randomId(), fileId: this.file.uuid),
      StringProp(file, fileId: this.file.uuid),
      isAlbedo: texData.useFlagsSimpleMode ? BoolProp(false, fileId: this.file.uuid) : null,
      flag: texData.useFlagsSimpleMode ? null : HexProp(textures.isNotEmpty ? textures.last.flag!.value : 0, fileId: this.file.uuid),
    )));
    file.onUndoableEvent();
    showToast("Added ${ddsFilesOrdered.length} DDS files");
  }
}

class _WtaWtpEditorState extends State<WtaWtpEditor> {
  _TexturesTableConfig? _texturesTableConfig;

  @override
  void initState() {
    widget.file.load().then((_) {
      _texturesTableConfig = _TexturesTableConfig(
        widget.file,
        basenameWithoutExtension(widget.file.path),
        widget.file.textures!
      );
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_texturesTableConfig == null) {
      return const Column(
        children: [
          SizedBox(height: 35),
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          )
        ],
      );
    }

    // return TableEditor(config: _texturesTableConfig!);
    return Stack(
      children: [
        TableEditor(config: _texturesTableConfig!),
        Positioned(
          bottom: 8,
          left: 8,
          width: 40,
          height: 40,
          child: FloatingActionButton(
          onPressed: _texturesTableConfig!.patchImportFolder,
          foregroundColor: getTheme(context).textColor,
          child: const Icon(Icons.create_new_folder),
        ),
        )
      ],
    );
  }
}
