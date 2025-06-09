
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:webview_windows/webview_windows.dart' as wv;

import '../../../../keyboardEvents/BetterShortcuts.dart';
import '../../../../stateManagement/events/jumpToEvents.dart';
import '../../../../stateManagement/openFiles/filesAreaManager.dart';
import '../../../../stateManagement/openFiles/openFilesManager.dart';
import '../../../../stateManagement/openFiles/types/TextFileData.dart';
import '../../../../utils/utils.dart';
import 'IframeTextEditorRendererMock.dart'
  if (dart.library.js_interop) 'IframeTextEditorRenderer.dart';
import 'TextEditorWebRenderer.dart';
import 'WebviewTextEditorRenderer.dart';

class WebviewTextFileEditor extends StatefulWidget {
  final TextFileData fileContent;
  final wv.WebviewController? webController;

  const WebviewTextFileEditor({super.key, required this.fileContent, required this.webController});

  @override
  State<WebviewTextFileEditor> createState() => _WebviewTextFileEditorState();
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

class _WebviewTextFileEditorState extends State<WebviewTextFileEditor> {
  late final TextEditorWebRenderer webRenderer;
  bool isUpdatingContent = false;
  StreamSubscription? msgSubscription;
  late StreamSubscription<JumpToEvent> goToLineSubscription;
  bool lineJumpSuccess = false;
  bool isRunning = true;
  FilesAreaManager? lastParentArea;
  bool _hasReceivedReady = false;
  

  @override
  void initState() {
    super.initState();
    var lang = _extensionToLanguage[extension(widget.fileContent.path)] ?? "";
    if (isDesktop) {
      webRenderer = WebviewTextEditorRenderer(widget.webController!, onWebMessage);
    }
    else if (isWeb) {
      webRenderer = IframeTextEditorRenderer(onWebMessage);
    }
    else {
      throw UnsupportedError("WebviewTextFileEditor is not supported on this platform");
    }
    webRenderer.loadPath("monaco_editor/index.html?lang=$lang").then((completed) {
      if (!completed)
        return;
      widget.fileContent.historyEnabled = false;
      widget.fileContent.text.addListener(onFileContentChange);
    });

    goToLineSubscription = jumpToEvents.listen(onGoToLineEvent);

    areasManager.subEvents.addListener(onOpenFileChange);
    onOpenFileChange();
  }

  @override
  void dispose() {
    webRenderer.dispose();
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
        if (_hasReceivedReady)
          return;
        _hasReceivedReady = true;
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
        break;
    }
  }

  void onFileContentChange() {
    if (isUpdatingContent)
      return;
    setEditorContent();
  }

  Future<void> setEditorContent() async {
    isUpdatingContent = true;
    await webRenderer.setEditorContent(widget.fileContent.text.value);
    if (isWeb)
      await Future.delayed(const Duration(milliseconds: 200));
    isUpdatingContent = false;
  }

  Future<void> postMessage(Map<String, dynamic> data) async {
    await webRenderer.postMessage(data);
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
      webRenderer.onFocus();
    else
      webRenderer.onBlur();
  }

  @override
  Widget build(BuildContext context) {
    return webRenderer.build(context);
  }
}

