
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
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

import '../../main.dart';
import '../../stateManagement/ChangeNotifierWidget.dart';
import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/undoable.dart';
import '../../utils/utils.dart';
import '../misc/SmoothScrollBuilder.dart';

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

Map<String, TextStyle> get _customTheme {
  var baseTheme = Theme.of(getGlobalContext()).brightness == Brightness.dark ? atomOneDarkTheme : atomOneLightTheme;
  baseTheme = Map.from(baseTheme);
  baseTheme["root"] = baseTheme["root"]!.copyWith(backgroundColor: Colors.transparent);
  return baseTheme;
}

class _TextFileEditorState extends ChangeNotifierState<TextFileEditor> {
  CodeController? controller;
  bool usesTabs = false;
  final scrollController = ScrollController();
  bool isOwnUpdate = false;
  bool isExternalUpdate = false;

  String tabsToSpaces(String text) => usesTabs
    ? text.replaceAll(RegExp("(?<=^\t*)\t", multiLine: true), "    ")
    : text;
  
  String spacesToTabs(String text) => usesTabs
    ? text.replaceAll(RegExp("(?<=^(    )*)    ", multiLine: true), "\t")
    : text;
  
  void onFileContentChange() {
    if (isOwnUpdate)
      return;
    var newText = tabsToSpaces(widget.fileContent.text);
    if (controller!.text == newText)
      return;
    isExternalUpdate = true;
    controller!.value = controller!.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: clamp(controller!.value.selection.baseOffset, 0, newText.length)),
    );
    isExternalUpdate = false;
  }

  @override
  void initState() {
    super.initState();
    widget.fileContent.load()
      .then((_) {
        usesTabs = RegExp("^\t+", multiLine: true).hasMatch(widget.fileContent.text);
        widget.fileContent.addListener(onFileContentChange);
        controller = CodeController(
          theme: _customTheme,
          language: _highlightLanguages[extension(widget.fileContent.path)],
          params: const EditorParams(tabSpaces: 4),
          text: tabsToSpaces(widget.fileContent.text),
          onChange: (text) {
            if (isExternalUpdate)
              return;
            text = spacesToTabs(text);
            if (text == widget.fileContent.text)
              return;
            isOwnUpdate = true;
            widget.fileContent.text = text;
            widget.fileContent.hasUnsavedChanges = true;
            undoHistoryManager.onUndoableEvent();
            isOwnUpdate = false;
          },
        );
        setState(() { });
      });
  }

  @override
  void dispose() {
    widget.fileContent.removeListener(onFileContentChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 35),
        controller != null
          ? Expanded(
            child: SmoothSingleChildScrollView(
              controller: scrollController,
              child: CodeField(
                controller: controller!,
              ),
            ),
          )
          : const SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          ),
      ],
    );
  }
}
