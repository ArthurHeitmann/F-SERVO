
import 'dart:async';
import 'dart:convert';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/xml.dart';
import 'package:path/path.dart';
import 'package:webview_windows/webview_windows.dart' as wv;

import '../../../keyboardEvents/BetterShortcuts.dart';
import '../../../main.dart';
import '../../../stateManagement/events/jumpToEvents.dart';
import '../../../stateManagement/openFiles/filesAreaManager.dart';
import '../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../stateManagement/openFiles/types/TextFileData.dart';
import '../../../stateManagement/preferencesData.dart';
import '../../../utils/assetDirFinder.dart';
import '../../../utils/utils.dart';
import '../../misc/ChangeNotifierWidget.dart';
import '../../misc/SmoothScrollBuilder.dart';
import '../../misc/onHoverBuilder.dart';

class TextFileEditor extends StatefulWidget {
  final TextFileData fileContent;

  const TextFileEditor({super.key, required this.fileContent});

  @override
  State<TextFileEditor> createState() => _TextFileEditorState();
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

class _TextFileEditorState extends State<TextFileEditor> {
  late bool useMonacoEditor;
  final webController = wv.WebviewController();
  bool isInitializing = true;
  bool isLoading = true;
  Future<bool>? supportVsCodeEditing;
  List<JumpToEvent> pendingJumpEvents = [];
  late StreamSubscription<JumpToEvent> jumpToSubscription;

  @override
  void initState() {
    var prefs = PreferencesData();
    useMonacoEditor = prefs.useMonacoEditor!.value;
    webController.initialize().whenComplete(() {
      isInitializing = false;
      webController.setBackgroundColor(Colors.transparent);
      onComponentReady();
    });
    widget.fileContent.load().whenComplete(() {
      isLoading = false;
      onComponentReady();
    });
    supportVsCodeEditing = hasVsCode();
    jumpToSubscription = jumpToEvents.listen((event) {
      if (event.file != widget.fileContent)
        return;
      if (!isReady)
        pendingJumpEvents.add(event);
    });
    super.initState();
  }

  @override
  void dispose() {
    webController.dispose();
    super.dispose();
  }

  bool get isReady => !isInitializing && !isLoading;

  void onComponentReady() async {
    if (!isReady)
      return;
    setState(() {});
    await waitForNextFrame();
    for (var event in pendingJumpEvents) {
      jumpToStream.add(event);
    }
    await jumpToSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (!isReady) {
      child = const SizedBox(
        height: 2,
        child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
      );
    }
    else if (webController.value.isInitialized && assetsDir != null && useMonacoEditor) {
      child = Expanded(child: _WebviewTextFileEditor(fileContent: widget.fileContent, webController: webController));
    }
    else {
      child = Expanded(child: _FallbackTextFileEditor(fileContent: widget.fileContent));
    }
    return Stack(
      children: [
        Column(
          children: [
            Container(height: 30, decoration: const BoxDecoration(color: Color(0xff1e1e1e))),
            child,
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

class _FallbackTextFileEditor extends ChangeNotifierWidget {
  late final TextFileData fileContent;

  _FallbackTextFileEditor({super.key, required this.fileContent}) : super(notifier: fileContent.text);

  @override
  ChangeNotifierState<_FallbackTextFileEditor> createState() => _FallbackTextFileEditorState();
}

class _FallbackTextFileEditorState extends ChangeNotifierState<_FallbackTextFileEditor> {
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

class _WebviewTextFileEditor extends StatefulWidget {
  final TextFileData fileContent;
  final wv.WebviewController webController;

  const _WebviewTextFileEditor({super.key, required this.fileContent, required this.webController});

  @override
  State<_WebviewTextFileEditor> createState() => _WebviewTextFileEditorState();
}

final _extensionToLanguage = {
  ".dart": "dart",
  ".java": "java",
  ".js": "javascript",
  ".ts": "typescript",
  ".json": "json",
  ".md": "markdown",
  ".py": "python",
  ".sh": "bash",
  ".xml": "xml",
  for (var ext in bxmExtensions)
    ext: "xml",
  ".rb": "ruby",
  ".html": "html",
  ".css": "css",
};

class _WebviewTextFileEditorState extends State<_WebviewTextFileEditor> {
  bool isUpdatingContent = false;
  StreamSubscription? msgSubscription;
  late StreamSubscription<JumpToEvent> goToLineSubscription;
  bool lineJumpSuccess = false;
  bool isRunning = true;
  FilesAreaManager? lastParentArea;

  @override
  void initState() {
    super.initState();
    var lang = _extensionToLanguage[extension(widget.fileContent.path)] ?? "";
    var url = "file:///${absolute(assetsDir!, "monaco_editor/index.html?lang=$lang")}".replaceAll("\\", "/");
    widget.webController.loadUrl(url);
    widget.webController.loadingState.contains(wv.LoadingState.navigationCompleted).then((completed) {
      if (!completed)
        return;
      widget.fileContent.historyEnabled = false;
      widget.fileContent.text.addListener(onFileContentChange);
      msgSubscription = widget.webController.webMessage.listen(onWebMessage);
    });

    goToLineSubscription = jumpToEvents.listen(onGoToLineEvent);

    areasManager.subEvents.addListener(onOpenFileChange);
    onOpenFileChange();
  }

  @override
  void dispose() {
    widget.fileContent.text.removeListener(onFileContentChange);
    msgSubscription?.cancel();
    goToLineSubscription.cancel();
    areasManager.subEvents.removeListener(onOpenFileChange);
    lastParentArea?.currentFile.removeListener(onCurrentFileChange);
    super.dispose();
  }

  Future<void> onGoToLineEvent(JumpToEvent event) async {
    if (event.file != widget.fileContent)
      return;
    if (event is! JumpToLineEvent)
      return;
    var retryUntil = DateTime.now().add(const Duration(seconds: 1));
    lineJumpSuccess = false;
    while (!lineJumpSuccess && DateTime.now().isBefore(retryUntil)) {
      await postMessage({
        "type": "jumpToLine",
        "line": event.line,
      });
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void onWebMessage(dynamic msg) {
    var data = msg as Map;
    var type = data["type"] as String?;
    switch (type) {
      case null:
        break;
      case "ready":
        setEditorContent();
        break;
      case "change":
        if (isUpdatingContent)
          return;
        var content = data["value"] as String;
        isUpdatingContent = true;
        widget.fileContent.text.value = content;
        isUpdatingContent = false;
        widget.fileContent.setHasUnsavedChanges(true);
        break;
      case "keydown":
        var event = data["event"] as Map;
        var key = event["key"] as String;
        var ctrl = event["ctrlKey"] as bool;
        var shift = event["shiftKey"] as bool;
        var alt = event["altKey"] as bool;
        var meta = event["metaKey"] as bool;
        var logicalKey = {
          "w": LogicalKeyboardKey.keyW,
          "s": LogicalKeyboardKey.keyS,
          "tab": LogicalKeyboardKey.tab,
        }[key.toLowerCase()];
        if (logicalKey == null) {
          return;
        }
        var keyEvent = ManualKeyEvent(
          logicalKey,
          ctrl: ctrl,
          shift: shift,
          alt: alt,
          meta: meta,
        );
        BetterShortcuts.sendKeyEvent(keyEvent);
        break;
      case "jumped":
        lineJumpSuccess = true;
        break;
      default:
        print("Unknown command: $type");
        break;
    }
  }

  void onFileContentChange() {
    if (isUpdatingContent)
      return;
    setEditorContent();
  }

  Future<void> setEditorContent() async {
    var encoded = jsonEncode(widget.fileContent.text.value);
    isUpdatingContent = true;
    await widget.webController.executeScript("window.textEditor.setValue($encoded)");
    isUpdatingContent = false;
  }

  Future<void> postMessage(Map<String, dynamic> data) async {
    await widget.webController.postWebMessage(jsonEncode(data));
  }

  void onOpenFileChange() {
    var parentArea = areasManager.getAreaOfFile(widget.fileContent);
    if (parentArea == lastParentArea)
      return;
    lastParentArea?.currentFile.removeListener(onCurrentFileChange);
    parentArea?.currentFile.addListener(onCurrentFileChange);
    lastParentArea = parentArea;
    onCurrentFileChange();
  }

  void onCurrentFileChange() {
    bool isVisible = lastParentArea?.currentFile.value == widget.fileContent;
    if (isVisible == isRunning)
      return;
    isRunning = isVisible;
    if (isVisible)
      widget.webController.resume();
    else
      widget.webController.suspend();
  }

  @override
  Widget build(BuildContext context) {
    return wv.Webview(
      widget.webController,
    );
  }
}
