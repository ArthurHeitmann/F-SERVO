
import 'dart:async';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/xml.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:path/path.dart';

import '../../../../main.dart';
import '../../../../stateManagement/events/jumpToEvents.dart';
import '../../../../stateManagement/openFiles/types/TextFileData.dart';
import '../../../../utils/utils.dart';
import '../../../misc/ChangeNotifierWidget.dart';
import '../../../misc/SmoothScrollBuilder.dart';

class FallbackTextFileEditor extends ChangeNotifierWidget {
  late final TextFileData fileContent;

  FallbackTextFileEditor({super.key, required this.fileContent}) : super(notifier: fileContent.text);

  @override
  ChangeNotifierState<FallbackTextFileEditor> createState() => _FallbackTextFileEditorState();
}

class _FallbackTextFileEditorState extends ChangeNotifierState<FallbackTextFileEditor> {
  late CodeController controller;
  final scrollController = ScrollController();
  final focus = FocusNode();
  StreamSubscription<JumpToEvent>? goToLineSubscription;
  bool usesTabs = false;
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
    var newText = tabsToSpaces(widget.fileContent.text.value);
    if (controller.text == newText)
      return;
    isExternalUpdate = true;
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: clamp(controller.value.selection.baseOffset, 0, newText.length)),
    );
    isExternalUpdate = false;
  }

  void onControllerTextChanged(text) {
    if (isExternalUpdate)
      return;
    text = spacesToTabs(text);
    if (text == widget.fileContent.text.value)
      return;
    isOwnUpdate = true;
    widget.fileContent.text.value = text;
    widget.fileContent.setHasUnsavedChanges(true);
    widget.fileContent.cursorOffset = controller.selection.baseOffset;
    widget.fileContent.onUndoableEvent();
    isOwnUpdate = false;
  }

  @override
  void initState() {
    super.initState();

    goToLineSubscription = jumpToEvents.listen(onGoToLineEvent);

    usesTabs = RegExp("^\t+", multiLine: true).hasMatch(widget.fileContent.text.value);
    widget.fileContent.text.addListener(onFileContentChange);
    controller = CodeController(
      language: _highlightLanguages[extension(widget.fileContent.path)],
      params: const EditorParams(tabSpaces: 4),
      text: tabsToSpaces(widget.fileContent.text.value),
    );
  }

  @override
  void dispose() {
    widget.fileContent.text.removeListener(onFileContentChange);
    goToLineSubscription?.cancel();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> onGoToLineEvent(JumpToEvent event) async {
    if (event.file != widget.fileContent)
      return;
    if (event is! JumpToLineEvent)
      return;
    await waitForNextFrame();
    var text = controller.text;
    int charStartPos = 0;
    int charEndPos = text.indexOf("\n");
    String currentLine = text.substring(charStartPos, charEndPos);
    int currentLineNum = 1;
    while (currentLineNum < event.line) {
      charStartPos = charEndPos + 1;
      if (charStartPos >= text.length)
        return;
      charEndPos = text.indexOf("\n", charStartPos);
      currentLine = text.substring(charStartPos, charEndPos);
      currentLineNum++;
    }
    var selection = TextSelection(
      // offset: charStartPos,
      baseOffset: charStartPos,
      extentOffset: charStartPos + currentLine.length,
    );

    // select the line
    var globalContext = getGlobalContext();
    // ignore: use_build_context_synchronously
    FocusScope.of(globalContext).requestFocus(focus);
    setState(() {});
    controller.value = controller.value.copyWith(
      selection: selection,
    );

    // scroll to the line
    var scrollableTotalHeight = scrollController.position.maxScrollExtent;
    var totalLines = text.split("\n").length;
    var lineHeight = scrollableTotalHeight / totalLines;
    var scrollOffset = lineHeight * (event.line - 1);
    await scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SmoothSingleChildScrollView(
      controller: scrollController,
      child: suppressUndoRedo(
        child: CodeTheme(
          data: CodeThemeData(styles: _customTheme),
          child: CodeField(
            controller: controller,
            focusNode: focus,
            onChanged: onControllerTextChanged,
            lineNumberBuilder: (line, style) => TextSpan(
              text: line.toString(),
              style: style?.copyWith(
                fontSize: 12,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget suppressUndoRedo({ required Widget child }) {
    return Focus(
      onKey: (node, event) {
        if (event is! RawKeyDownEvent)
          return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.keyZ && event.isControlPressed)
          return KeyEventResult.handled;
        if (event.logicalKey == LogicalKeyboardKey.keyY && event.isControlPressed)
          return KeyEventResult.handled;
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
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
  for (var ext in bxmExtensions)
    ext: xml,
  ".rb": ruby,
};

Map<String, TextStyle> get _customTheme {
  var baseTheme = Theme.of(getGlobalContext()).brightness == Brightness.dark ? atomOneDarkTheme : atomOneLightTheme;
  baseTheme = Map.from(baseTheme);
  baseTheme["root"] = baseTheme["root"]!.copyWith(backgroundColor: Colors.transparent);
  return baseTheme;
}
