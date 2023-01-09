
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../stateManagement/Property.dart';
import '../../../stateManagement/nestedNotifier.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../stateManagement/otherFileTypes/wtaData.dart';
import '../../../stateManagement/undoable.dart';
import '../../../utils/utils.dart';
import 'genericTable/tableEditor.dart';

class WtaWtpEditor extends StatefulWidget {
  final WtaWtpData file;

  const WtaWtpEditor({ super.key, required this.file });

  @override
  State<WtaWtpEditor> createState() => _WtaWtpEditorState();
}

class _TexturesTableConfig with CustomTableConfig {
  final WtaWtpTextures texData;
  final NestedNotifier<WtaTextureEntry> textures;

  _TexturesTableConfig(String name, this.texData)
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
    rowCount = NumberProp(textures.length, true)
      ..changesUndoable = false;
    textures.addListener(() => rowCount.value = textures.length);
  }

  void dispose() {
    rowCount.dispose();
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
      HexProp(randomId()),
      StringProp(""),
      isAlbedo: texData.useFlagsSimpleMode ? BoolProp(false) : null,
      flag: texData.useFlagsSimpleMode ? null : HexProp(textures.isNotEmpty ? textures.last.flag!.value : 0),
    ));
    undoHistoryManager.onUndoableEvent();
  }

  @override
  void onRowRemove(int index) {
    textures.removeAt(index);
    undoHistoryManager.onUndoableEvent();
  }
}

class _WtaWtpEditorState extends State<WtaWtpEditor> {
  _TexturesTableConfig? _texturesTableConfig;

  @override
  void initState() {
    widget.file.load().then((_) {
      _texturesTableConfig = _TexturesTableConfig(
        basenameWithoutExtension(widget.file.path),
        widget.file.textures!
      );
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    _texturesTableConfig?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_texturesTableConfig == null) {
      return Column(
        children: const [
          SizedBox(height: 35),
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          )
        ],
      );
    }

    return TableEditor(config: _texturesTableConfig!);
  }
}
