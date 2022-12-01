
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../stateManagement/openFileTypes.dart';
import '../../../utils/utils.dart';
import '../../misc/debugContainer.dart';
import '../../theme/customTheme.dart';
import 'AudioFileEditor.dart';

class WemFileEditor extends StatefulWidget {
  final WemFileData wem;
  final bool lockControls;
  final bool topPadding;
  final bool showOverride;

  const WemFileEditor({ super.key, required this.wem, this.lockControls = false, this.topPadding = false, this.showOverride = true });

  @override
  State<WemFileEditor> createState() => _WemFileEditorState();
}

class _WemFileEditorState extends State<WemFileEditor> {
  @override
  void initState() {
    widget.wem.overrideData.addListener(_onOverrideChanged);
    super.initState();
  }

  @override
  void dispose() {
    widget.wem.overrideData.removeListener(_onOverrideChanged);
    super.dispose();
  }

  void _onOverrideChanged() => setState(() {});

  Future<void> _pickOverride() async {
    var files = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      allowedExtensions: ["wav"],
    );
    if (files == null)
      return;
    var file = files.files.first;
    if (!file.path!.endsWith(".wav")) {
      showToast("Please select a .wav file");
      return;
    }
    var wavFile = WavFileData(file.path!);
    await wavFile.load();
    widget.wem.overrideData.value = wavFile;
  }

  @override
  Widget build(BuildContext context) {
    var audioEditor = Column(
      children: [
        AudioFileEditor(
          file: widget.wem,
          lockControls: widget.lockControls,
          additionalControls: widget.showOverride ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: _pickOverride,
                style: getTheme(context).dialogPrimaryButtonStyle,
                child: const Text("Select Override"),
              ),
              const SizedBox(width: 10),
              if (widget.wem.overrideData.value != null)
                ElevatedButton(
                  onPressed: () => widget.wem.overrideData.value = null,
                  style: getTheme(context).dialogSecondaryButtonStyle,
                  child: const Text("Remove"),
                ),
            ],
          ) : null,
        ),
        if (widget.showOverride && widget.wem.overrideData.value != null) ...[
          AudioFileEditor(
            key: Key(widget.wem.overrideData.value!.uuid),
            file: widget.wem.overrideData.value!,
            lockControls: widget.lockControls,
            additionalControls: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () => widget.wem.applyOverride(),
                  style: getTheme(context).dialogPrimaryButtonStyle,
                  child: const Text("Apply Override"),
                ),
              ],
            ),
          ),
        ]
      ],
    );
    if (widget.topPadding) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: audioEditor,
      );
    }
    return audioEditor;
  }
}
