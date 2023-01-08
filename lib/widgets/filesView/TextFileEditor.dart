
import 'dart:async';

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
import '../../stateManagement/events/jumpToEvents.dart';
import '../../stateManagement/openFileTypes.dart';
import '../../stateManagement/undoable.dart';
import '../../utils/assetDirFinder.dart';
import '../../utils/utils.dart';
import '../misc/SmoothScrollBuilder.dart';
import '../misc/onHoverBuilder.dart';

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
  final scrollController = ScrollController();
  final focus = FocusNode();
  StreamSubscription<JumpToEvent>? goToLineSubscription;
  Future<void>? fileLoaded;
  bool usesTabs = false;
  bool isOwnUpdate = false;
  bool isExternalUpdate = false;
  Future<bool>? supportVsCodeEditing;

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

    goToLineSubscription = jumpToEvents.listen(onGoToLineEvent);

    supportVsCodeEditing = hasVsCode();

    var loadedCompleter = Completer<void>();
    fileLoaded = loadedCompleter.future;
    widget.fileContent.load()
      .then((_) {
        loadedCompleter.complete();
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
    goToLineSubscription?.cancel();
    super.dispose();
  }

  Future<void> onGoToLineEvent(JumpToEvent event) async {
    if (event.file != widget.fileContent)
      return;
    if (event is! JumpToLineEvent)
      return;
    if (controller == null)
      return;
    await waitForNextFrame();
    var text = controller!.text;
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
    controller!.value = controller!.value.copyWith(
      selection: selection,
    );

    // scroll to the line
    var scrollableTotalHeight = scrollController.position.maxScrollExtent;
    var totalLines = text.split("\n").length;
    var lineHeight = scrollableTotalHeight / totalLines;
    var scrollOffset = lineHeight * (event.line - 1);
    scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 35),
            controller != null
              ? Expanded(
                child: SmoothSingleChildScrollView(
                  controller: scrollController,
                  child: CodeField(
                    controller: controller!,
                    focusNode: focus,
                    lineNumberBuilder: (line, style) => TextSpan(
                      text: line.toString(),
                      style: style?.copyWith(
                        fontSize: 12,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ),
              )
              : const SizedBox(
                height: 2,
                child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
              ),
          ],
        ),
        FutureBuilder(
          future: supportVsCodeEditing,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == true)
              return Positioned(
                top: 16,
                right: 16,
                child: OnHoverBuilder(
                  builder: (context, isHovering) => AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isHovering ? 1 : 0.5,
                    child: IconButton(
                      icon: Image.asset("assets/images/vscode.png", width: 32, height: 32),
                      onPressed: () => openInVsCode(widget.fileContent.path),
                    ),
                  ),
                ),
              );
            return const SizedBox();
          },
        ),
      ],
    );
  }
}
