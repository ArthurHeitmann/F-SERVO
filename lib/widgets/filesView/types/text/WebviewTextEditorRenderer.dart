
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:webview_windows/webview_windows.dart' as wv;

import '../../../../utils/assetDirFinder.dart';
import 'TextEditorWebRenderer.dart';

class WebviewTextEditorRenderer extends TextEditorWebRenderer {
  final wv.WebviewController _webController;
  final void Function(dynamic data) _onWebMessage;
  StreamSubscription? _msgSubscription;

  WebviewTextEditorRenderer(this._webController, this._onWebMessage);

  @override
  Future<bool> loadPath(String path) async {
    var url = "file:///${absolute(assetsDir!, path)}".replaceAll("\\", "/");
    print(url);
    await _webController.loadUrl(url);
    var navigationCompleted = await _webController.loadingState.contains(wv.LoadingState.navigationCompleted);
    if (navigationCompleted) {
      _msgSubscription = _webController.webMessage.listen(_onWebMessage);
    }
    return navigationCompleted;
  }

  @override
  Future<void> postMessage(Map<String, dynamic> data) async {
    await _webController.postWebMessage(jsonEncode(data));
  }

  @override
  Future<void> setEditorContent(String content) async {
    var encoded = jsonEncode(content);
    await _webController.executeScript("window.textEditor.setValue($encoded)");
  }

  @override
  void onFocus() {
    _webController.resume();
  }

  @override
  void onBlur() {
    _webController.suspend();
  }

  @override
  Widget build(BuildContext context) {
    return wv.Webview(_webController);
  }

  @override
  void dispose() {
    _msgSubscription?.cancel();
  }
}
