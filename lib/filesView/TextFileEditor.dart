
import 'package:flutter/material.dart';
import 'package:nier_scripts_editor/stateManagement/openFileContents.dart';

import '../stateManagement/nestedNotifier.dart';

class TextFileEditor extends ChangeNotifierWidget {
  late final FileTextContent fileContent;

  TextFileEditor({Key? key, required FileTextContent file}) : super(key: key, notifier: file) {
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
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 14,
          color: Colors.white
        ),
        text: widget.fileContent.text.replaceAll("\t", "    ")
      )
    );
  }
}
