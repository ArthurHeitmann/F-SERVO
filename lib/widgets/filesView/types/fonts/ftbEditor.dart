
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../stateManagement/openFiles/openFileTypes.dart';
import '../../../../stateManagement/openFiles/types/FtbFileData.dart';
import '../../../../stateManagement/openFiles/types/McdFileData.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../theme/customTheme.dart';
import 'FontsManager.dart';
import 'McdFontDebugger.dart';
import 'fontOverridesApply.dart';

class FtbEditor extends ChangeNotifierWidget {
  final FtbFileData file;

  FtbEditor({ super.key, required this.file }) : super(notifiers: [file.loadingState, McdData.fontChanges]);

  @override
  State<FtbEditor> createState() => _FtbEditorState();
}

class _FtbEditorState extends ChangeNotifierState<FtbEditor> {
  int activeTexture = 0;

  @override
  void initState() {
    widget.file.load();
    super.initState();
  }

  Future<void> addNewFontChars() async {
    var filesResult = await FilePicker.platform.pickFiles(
      dialogTitle: "Select font file",
      allowedExtensions: ["ttf", "otf"],
      type: FileType.custom,
      allowMultiple: false,
    );
    if (filesResult == null || filesResult.files.isEmpty)
      return;
    var fontFile = filesResult.files.first;
    await widget.file.addCharsFromFront(fontFile.path!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.file.loadingState.value != LoadingState.loaded) {
      return const Column(
        children: [
          SizedBox(height: 35),
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          ),
        ],
      );
    }
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          const SizedBox(height: 35),
          FontsManager(
            singleFontId: widget.file.ftbData!.fontId,
            showResolutionScale: false,
            additionalProps: [
              ("Global kerning", widget.file.ftbData!.kerning)
            ],
          ),
          Row(
            children: [
              const FontOverridesApplyButton(showText: true),
              const SizedBox(width: 30),
              TextButton.icon(
                onPressed: addNewFontChars,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(getTheme(context).textColor),
                  padding: WidgetStateProperty.all(const EdgeInsets.all(14))
                ),
                icon: const Icon(Icons.note_add),
                label: const Text("Add new characters from TTF/OTF file"),
              ),
            ],
          ),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: activeTexture > 0 ? () => setState(() => activeTexture--) : null,
                ),
                Expanded(
                  child: IndexedStack(
                    index: activeTexture,
                    children: [
                      for (var i = 0; i < widget.file.ftbData!.textures.length; i++)
                        McdFontDebugger(
                          key: UniqueKey(),
                          texturePath: widget.file.ftbData!.textures[i].extractedPngPath!,
                          fonts: [widget.file.ftbData!.asMcdFont(i)],
                        )
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: activeTexture < widget.file.ftbData!.textures.length - 1 ? () => setState(() => activeTexture++) : null,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
