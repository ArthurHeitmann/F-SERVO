
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:js_interop_utils/js_interop_utils.dart';
import 'package:path/path.dart';
import 'package:web/web.dart';

import '../utils/assetDirFinder.dart';
import 'MsgResult.dart';

@JS()
extension type _FallbackModule._(JSObject _) implements JSObject {
  external void onMessage(JSObject eventData, JSFunction postMessage);
}

class ServiceWorkerHelper {
  static late final ServiceWorkerHelper i;
  _FallbackModule? _fallbackModule;
  final Map<int, _Request> _requests = {};
  int _nextRequestId = 0;
  final List<(Map<String, JSAny?>, _Request)> _requestsQueue = [];
  int? _activeRequestId;

  ServiceWorkerHelper._();

  static Future<void> register() async {
    var navigator = window.navigator;
    if (!navigator.hasProperty("serviceWorker".toJS).toDart) {
      i = ServiceWorkerHelper._();
      print("Service worker not supported");
      return;
    }
    
    i = ServiceWorkerHelper._();
    
    EventStreamProvider("message").forTarget(navigator.serviceWorker).listen(i._onMessage);

    const attemptFor = Duration(milliseconds: 2500);
    const timePerAttempt = Duration(milliseconds: 500);
    final maxAttempts = attemptFor.inMilliseconds ~/ timePerAttempt.inMilliseconds;
    var gotResponse = false;
    for (int i = 0; i < maxAttempts; i++) {
      print("Sending echo request to service worker, attempt: ${i + 1} of $maxAttempts");
      var echo = await ServiceWorkerHelper.i._request("echo", {}, timeout: timePerAttempt);
      if (echo.isOk) {
        gotResponse = true;
        break;
      }
      await Future.delayed(timePerAttempt);
    }
    if (gotResponse) {
      print("Service worker ready");
      return;
    }
    print("Service worker not ready, falling back to fallback module");
    i._fallbackModule = (await importModule(join(assetsDir!, "web_worker", "dist", "worker_base.js").toJS).toDart) as _FallbackModule;

    var echo = await i._request("echo", {}, timeout: timePerAttempt);
    if (echo.isOk) {
      print("Fallback module ready");
      return;
    }
    print("Failed to initialize fallback module");
  }

  Future<MsgResult<Uint8List>> wemToWav(Uint8List wem) async {
    var buffer = _JSUint8Array2((wem as List<int>).toJS);
    var result = await _request("wem_to_wav", {"bytes": buffer});
    if (result.isError) {
      return result.error<Uint8List>();
    }
    var wav = (result.ok["bytes"] as JSUint8Array).toDart;
    return MsgResultOk(wav);
  }

  Future<MsgResult<Uint8List>> imgToPng(Uint8List wem, int? maxHeight) async {
    var buffer = _JSUint8Array2((wem as List<int>).toJS);
    var result = await _request("img_to_png", {
      "bytes": buffer,
      if (maxHeight != null)
        "maxHeight": maxHeight.toJS,
    });
    if (result.isError) {
      return result.error<Uint8List>();
    }
    var wav = (result.ok["bytes"] as JSUint8Array).toDart;
    return MsgResultOk(wav);
  }

  Future<MsgResult<Uint8List>> imgToDds(Uint8List wem, String compression, int mipmaps) async {
    var buffer = _JSUint8Array2((wem as List<int>).toJS);
    var result = await _request("img_to_dds", {
      "bytes": buffer,
      "compression": compression.toJS,
      "mipmaps": mipmaps.toJS,
    });
    if (result.isError) {
      return result.error<Uint8List>();
    }
    var wav = (result.ok["bytes"] as JSUint8Array).toDart;
    return MsgResultOk(wav);
  }

  Future<MsgResult<JSObject>> _request(String method, Map<String, JSAny?> args, {Duration timeout = const Duration(seconds: 5)}) async {
    var requestId = _nextRequestId++;
    var message = <String, JSAny?>{
      "id": requestId.toJS,
      "type": method.toJS,
      "args": _mapToJS(args),
    };
    var request = _Request(timeout);
    _requests[requestId] = request;
    _requestsQueue.add((message, request));
    _tryDequeueRequest();
    MsgResult<JSObject> result;
    result = await request.completer.future;
    if (result.isTimeoutError) {
      _requests.remove(requestId);
      if (requestId == _activeRequestId) {
        _activeRequestId = null;
        _tryDequeueRequest();
      }
    }
    return result;
  }

  void _tryDequeueRequest() {
    if (_activeRequestId != null)
      return;
    if (_requestsQueue.isEmpty)
      return;
    var (message, request) = _requestsQueue.removeAt(0);
    var requestId = (message["id"] as JSNumber).toDartInt;
    _activeRequestId = requestId;
    request.startTimeout();
    _postMessage(message, request);
  }

  void _postMessage(Map<String, JSAny?> message, _Request request) {
    if (_fallbackModule != null) {
      var callback = _onMessage.toJS;
      _fallbackModule!.onMessage(_mapToJS(message), callback);
      return;
    }
    if (window.navigator.serviceWorker.controller == null) {
      request.onTimeout();
      return;
    }
    window.navigator.serviceWorker.controller!.postMessage(_mapToJS(message));
  }

  void _onMessage(JSAny event) {
    _WorkerMessage data;
    if (event.isA<MessageEvent>()) {
      data = (event as MessageEvent).data as _WorkerMessage;
    }
    else if (event.isA<JSObject>()) {
      var eventData = event as JSObject;
      if (!eventData.hasProperty("id".toJS).toDart || !eventData.hasProperty("args".toJS).toDart) {
        return;
      }
      data = eventData as _WorkerMessage;
    }
    else {
      return;
    }
    var id = data.id.toDartInt;
    var request = _requests[id];
    if (request == null) {
      return;
    }
    request.onData(data.args);
    _requests.remove(id);
    _activeRequestId = null;
    _tryDequeueRequest();
  }
}

class _Request {
  final Duration timeoutDuration;
  Timer? timeout;
  final Completer<MsgResult<JSObject>> completer;

  _Request(this.timeoutDuration) :
    completer = Completer<MsgResult<JSObject>>();
  
  void startTimeout() {
    if (timeout != null) {
      throw Exception("Timeout already started");
    }
    timeout = Timer(timeoutDuration, onTimeout);
  }

  void onTimeout() {
    if (!completer.isCompleted) {
      completer.complete(MsgResultTimeoutError("Request timed out"));
    }
  }

  void onData(JSObject args) {
    if (completer.isCompleted) {
      return;
    }
    timeout?.cancel();
    completer.complete(MsgResultOk<JSObject>(args));
  }
}

@JS()
extension type _WorkerMessage._(JSObject _) implements JSObject {
  external JSNumber id;
  external JSString type;
  external JSObject args;
}

JSObject _mapToJS(Map<String, JSAny?> map) {
  var jsMap = JSObject();
  for (var entry in map.entries) {
    jsMap.setProperty(entry.key.toJS, entry.value);
  }
  return jsMap;
}

@JS("Uint8Array")
extension type _JSUint8Array2._(JSObject _) implements JSObject {
  external _JSUint8Array2(JSArray array);
}
