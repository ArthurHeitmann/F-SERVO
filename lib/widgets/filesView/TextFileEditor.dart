
import 'package:flutter/material.dart';

import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFileTypes.dart';

class TextFileEditor extends ChangeNotifierWidget {
  late final TextFileData fileContent;

  TextFileEditor({Key? key, required this.fileContent}) : super(key: key, notifier: fileContent);

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
        ),
        text: widget.fileContent.text.replaceAll("\t", "    ")
      )
    );
  }
}
