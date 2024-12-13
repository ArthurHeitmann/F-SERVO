
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/textures/ddsConverter.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/events/statusInfo.dart';
import '../../../stateManagement/hierarchy/FileHierarchy.dart';
import '../../../stateManagement/listNotifier.dart';
import '../../../stateManagement/openFiles/types/WtaWtpData.dart';
import '../../../utils/utils.dart';
import '../../misc/ChangeNotifierWidget.dart';
import '../../misc/expandOnHover.dart';
import '../../misc/imagePreviewBuilder.dart';
import '../../propEditors/propTextField.dart';
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
    subTitleWidget = _WtpDatPaths(wtpDatsPath: texData.wtpDatsPath);
    columnNames = [
      "ID", "PNG", "Path", "", "",
      if (texData.hasAnySimpleModeFlags)
        "Is Albedo?",
      if (!texData.useFlagsSimpleMode)
        "Flags",
    ];
    columnFlex = [
      3, 2, 14, 1, 1,
      if (texData.hasAnySimpleModeFlags)
        3,
      if (!texData.useFlagsSimpleMode)
        3,
    ];
    rowCount = NumberProp(textures.length, true, fileId: null);
    textures.addListener(() => rowCount.value = textures.length);
  }

  @override
  RowConfig rowPropsGenerator(int index) {
    return RowConfig(
      key: Key(textures[index].uuid),
      cells: [
        textures[index].id != null
          ? PropCellConfig(prop: textures[index].id!)
          : CustomWidgetCellConfig(const SizedBox.shrink()),
        _TexturePreviewCell(textures[index].path),
        PropCellConfig(prop: textures[index].path, options: const PropTFOptions(isFilePath: true)),
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
      NumberProp(randomId(), true, fileId: file.uuid),
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

  Future<void> patchFromFolder() async {
    var paths = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Select folder with DDS files",
    );
    if (paths == null)
      return;
    await file.textures!.patchFromFolder(paths);
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
          bottom: 16,
          left: 16,
          width: 40,
          height: 40,
          child: FloatingActionButton(
            onPressed: _texturesTableConfig!.patchFromFolder,
            foregroundColor: getTheme(context).textColor,
            tooltip: "Replace or add all from folder",
            child: const Icon(Icons.folder_special),
          ),
        )
      ],
    );
  }
}

class _TexturePreviewCell extends CellConfig {
  final StringProp path;

  _TexturePreviewCell(this.path);
  
  @override
  Widget makeWidget() {
    return _TexturePreview(path: path);
  }
  
  @override
  String toExportString() {
    return "";
  }

}

class _TexturePreview extends ChangeNotifierWidget {
  final StringProp path;

  _TexturePreview({required this.path}) : super(notifier: path);

  @override
  State<_TexturePreview> createState() => __TexturePreviewState();
}

class __TexturePreviewState extends ChangeNotifierState<_TexturePreview> {
  @override
  Widget build(BuildContext context) {
    return ImagePreviewBuilder(
      maxHeight: 256,
      path: widget.path.value,
      builder: (context, data, state) {
        if (state == ImagePreviewState.loading)
          return const SizedBox.shrink();
        if (state == ImagePreviewState.error)
          return const Icon(Icons.error_outline);
        if (state == ImagePreviewState.notFound)
          return const Icon(Icons.help_outline);
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100, maxHeight: 30),
          child: ExpandOnHover(
            size: 30,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  var savePath = await FilePicker.platform.saveFile(
                    dialogTitle: "Save PNG",
                    type: FileType.custom,
                    allowedExtensions: ["png"],
                    fileName: "${basenameWithoutExtension(widget.path.value)}.png",
                  );
                  if (savePath == null)
                    return;
                  await texToPng(widget.path.value, pngPath: savePath);
                  messageLog.add("Saved PNG ${basename(savePath)}");
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.memory(data!),
                ),
              ),
            ),
          )
        );
      },
    );
  }
}

class _WtpDatPaths extends ChangeNotifierWidget {
  final ValueNotifier<List<String>?> wtpDatsPath;
  
  _WtpDatPaths({required this.wtpDatsPath}) : super(notifier: wtpDatsPath);

  @override
  State<_WtpDatPaths> createState() => __WtpDatPathsState();
}

class __WtpDatPathsState extends ChangeNotifierState<_WtpDatPaths> {
  void _openDat(String path) async {
    var file = await openHierarchyManager.openFile(path);
    if (file == null)
      return;
    openHierarchyManager.setSelectedEntry(file);
    showToast("Opened ${basename(path)} to sidebar");
  }

  @override
  Widget build(BuildContext context) {
    var paths = widget.wtpDatsPath.value;
    if (paths == null)
      return const SizedBox.shrink();
    return Row(
      children: [
        const Text("WTP inside DTT: "),
        for (var path in paths)
          if (path != paths.last) ...[
            Flexible(
              child: TextButton(
                onPressed: () => _openDat(path),
                child: Text(basename(path), overflow: TextOverflow.ellipsis),
              ),
            ),
            Text(" > ", style: TextStyle(fontWeight: FontWeight.w900),),
          ]
          else
            Flexible(
              child: Text(basename(path), overflow: TextOverflow.ellipsis),
            ),
      ],
    );
  }
}
