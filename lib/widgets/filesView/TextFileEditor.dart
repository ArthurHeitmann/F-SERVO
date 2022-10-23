
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/xml.dart';
import 'package:path/path.dart';

import '../../widgets/theme/customTheme.dart';
import '../../main.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFileTypes.dart';
import '../misc/SmoothSingleChildScrollView.dart';

class TextFileEditor extends ChangeNotifierWidget {
  late final TextFileData fileContent;

  TextFileEditor({Key? key, required this.fileContent}) : super(key: key, notifier: fileContent);

  @override
  ChangeNotifierState<TextFileEditor> createState() => _TextFileEditorState();
}

final _highlightLanguages = {
  ".dart": dart,
  ".java": java,
  ".js": javascript,
  ".json": json,
  ".md": markdown,
  ".py": python,
  ".sh": bash,
  ".xml": xml,
  ".rb": ruby,
};

Map<String, TextStyle> get _customTheme => {
  ...atomOneDarkTheme,
  "root": TextStyle(color: Color(0xffabb2bf), backgroundColor: getTheme(getGlobalContext()).editorBackgroundColor),
};

class _TextFileEditorState extends ChangeNotifierState<TextFileEditor> {
  CodeController? controller;
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.fileContent.load()
      .then((_) {
        controller = CodeController(
          // theme: _customTheme,
          theme: atomOneDarkTheme,
          language: _highlightLanguages[extension(widget.fileContent.path)],
          params: EditorParams(tabSpaces: 4),
          text: widget.fileContent.text,
          onChange: (text) {
            if (text == widget.fileContent.text)
              return;
            widget.fileContent.text = text;
            widget.fileContent.hasUnsavedChanges = true;
          },
        );
        setState(() { });
      });
  }

  @override
  Widget build(BuildContext context) {
    return controller != null
      ? SmoothSingleChildScrollView(
        controller: scrollController,
        child: CodeField(
          controller: controller!,
        ),
      )
      : Center(
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(Size(150, 150)),
          child: Opacity(
            opacity: 0.25,
            child: Image(
              image: AssetImage("assets/logo/pod_alpha.png"),
            ),
          )
        ),
      );
  }
}
