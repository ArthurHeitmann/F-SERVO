
import 'package:flutter/material.dart';

import 'TextEditorWebRenderer.dart';

class IframeTextEditorRenderer extends TextEditorWebRenderer {
  IframeTextEditorRenderer(void Function(dynamic data) onWebMessage) {
    throw UnimplementedError("Called function on IframeTextEditorRendererMock, which is a mock class.");
  }

  @override
  Future<bool> loadPath(String path) async {
    throw UnimplementedError("Called function on IframeTextEditorRendererMock, which is a mock class.");
  }

  @override
  Future<void> postMessage(Map<String, dynamic> data) async {
    throw UnimplementedError("Called function on IframeTextEditorRendererMock, which is a mock class.");
  }

  @override
  Future<void> setEditorContent(String content) async {
    throw UnimplementedError("Called function on IframeTextEditorRendererMock, which is a mock class.");
  }

  @override
  void onFocus() {
    throw UnimplementedError("Called function on IframeTextEditorRendererMock, which is a mock class.");
  }

  @override
  void onBlur() {
    throw UnimplementedError("Called function on IframeTextEditorRendererMock, which is a mock class.");
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError("Called function on IframeTextEditorRendererMock, which is a mock class.");
  }

  @override
  void dispose() {
    throw UnimplementedError("Called function on IframeTextEditorRendererMock, which is a mock class.");
  }
}
