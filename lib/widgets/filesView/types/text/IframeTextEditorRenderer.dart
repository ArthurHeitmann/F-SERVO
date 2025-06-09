
import 'dart:async';
import 'dart:convert';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:js_interop_utils/js_interop_utils.dart';
import 'package:path/path.dart';
import 'package:web/web.dart';

import '../../../../utils/assetDirFinder.dart';
import 'TextEditorWebRenderer.dart';

class IframeTextEditorRenderer extends TextEditorWebRenderer {
  static int _nextWindowId = 0;
  static Map<String, IframeTextEditorRenderer> _renderers = {};
  final String _windowId = "${_nextWindowId++}";
  HTMLIFrameElement? _iframe;
  String? url;
  final _loadCompleter = Completer<bool>();
  late final StreamSubscription<Event> _streamSubscription;
  final void Function(dynamic data) _onWebMessage;
  StreamSubscription<Event>? _onLoaded;

  IframeTextEditorRenderer(this._onWebMessage) {
    _renderers[_windowId] = this;
    ui_web.platformViewRegistry.registerViewFactory("monaco-editor", (int viewId, {Object? params}) {
      var windowId = (params! as Map)["windowId"] as String?;
      var renderer = _renderers[windowId]!;
      return renderer._makeIframe();
    });
    _streamSubscription = EventStreamProvider("message").forTarget(window).listen(_onMessage);
  }

  HTMLIFrameElement _makeIframe() {
    if (url == null)
      throw ArgumentError("URL must be set before creating the iframe");
    _iframe = HTMLIFrameElement()
      ..width = "100%"
      ..height = "100%"
      ..style.border = "none"
      ..src = url!;
    _onLoaded = EventStreamProvider("load").forTarget(_iframe).listen((event) {
      if (!_loadCompleter.isCompleted)
        _loadCompleter.complete(true);
    });
    return _iframe!;
  }

  @override
  Future<bool> loadPath(String path) async {
    var url = join(assetsDir!, path);
    if (url.contains("?"))
      url += "&windowId=$_windowId";
    else
      url += "?windowId=$_windowId";
    this.url = url;
    return _loadCompleter.future;
  }

  @override
  Future<void> postMessage(Map<String, dynamic> data) async {
    data["windowId"] = _windowId;
    var encoded = jsonEncode(data);
    window.postMessage(encoded.toJS, "*".toJS);
  }

  @override
  Future<void> setEditorContent(String content) async {
    await postMessage({
      "type": "setContent",
      "value": content,
    });
  }

  @override
  void onFocus() {
  }

  @override
  void onBlur() {
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: "monaco-editor",
      creationParams: {"windowId": _windowId},
    );
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    _onLoaded?.cancel();
    _renderers.remove(_windowId);
  }

  void _onMessage(Event event) {
    if (!event.isA<MessageEvent>())
      return;
    var data = (event as MessageEvent).data;
    if (!data.isA<JSObject>())
      return;
    var map = (data as JSObject).toMap();
    var windowId = (map["windowId"] as JSString?)?.toDart;
    if (windowId != _windowId) {
      return; // Ignore messages from other windows
    }
    _onWebMessage(map);
  }
}
