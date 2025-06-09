
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart' as wv;

import '../../../../stateManagement/events/jumpToEvents.dart';
import '../../../../stateManagement/openFiles/types/TextFileData.dart';
import '../../../../stateManagement/preferencesData.dart';
import '../../../../utils/assetDirFinder.dart';
import '../../../../utils/utils.dart';
import '../../../misc/onHoverBuilder.dart';
import 'FallbackTextFileEditor.dart';
import 'WebviewTextFileEditor.dart';

class TextFileEditor extends StatefulWidget {
  final TextFileData fileContent;

  const TextFileEditor({super.key, required this.fileContent});

  @override
  State<TextFileEditor> createState() => _TextFileEditorState();
}

class _TextFileEditorState extends State<TextFileEditor> {
  late bool useMonacoEditor;
  late final wv.WebviewController? webController;
  bool isInitializing = true;
  bool isLoading = true;
  Future<bool>? supportVsCodeEditing;
  List<JumpToEvent> pendingJumpEvents = [];
  late StreamSubscription<JumpToEvent> jumpToSubscription;

  @override
  void initState() {
    var prefs = PreferencesData();
    useMonacoEditor = prefs.useMonacoEditor!.value;
    if (isDesktop) {
      webController = wv.WebviewController();
      webController!.initialize().whenComplete(() {
        isInitializing = false;
        webController!.setBackgroundColor(Colors.transparent);
        onComponentReady();
      });
    }
    else {
      webController = null;
      isInitializing = false;
      isLoading = false;
    }

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
    webController?.dispose();
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
    else if ((isWeb || (webController?.value.isInitialized ?? false) && assetsDir != null) && useMonacoEditor) {
      child = Expanded(child: WebviewTextFileEditor(fileContent: widget.fileContent, webController: webController));
    }
    else {
      child = Expanded(child: FallbackTextFileEditor(fileContent: widget.fileContent));
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
                      onPressed: () => openInVsCode(widget.fileContent.vsCodePath),
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
