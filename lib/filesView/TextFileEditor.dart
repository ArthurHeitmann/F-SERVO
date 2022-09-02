
import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/stateManagement/openFileContents.dart';
import 'package:nier_scripts_editor/stateManagement/openFilesManager.dart';

import '../stateManagement/nestedNotifier.dart';

class TextFileEditor extends ChangeNotifierWidget {
  late final FileTextContent fileContent;

  TextFileEditor({Key? key, required OpenFileData file}) : super(key: key, notifier: fileContentsManager.getContent(file)!) {
    assert(notifier is FileTextContent);
    fileContent = notifier as FileTextContent;
  }

  @override
  ChangeNotifierState<TextFileEditor> createState() => _TextFileEditorState();
}

class _TextFileEditorState extends ChangeNotifierState<TextFileEditor> {
  @override
  void initState() {
    super.initState();
    widget.fileContent.load();
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.fileContent.text);
  }
}
