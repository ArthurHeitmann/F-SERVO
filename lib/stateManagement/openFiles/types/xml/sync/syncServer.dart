
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../events/statusInfo.dart';

const _wsPort = 1547;

WebSocket? _activeSocket;
ValueNotifier<bool> canSync = ValueNotifier<bool>(false);

var _wsMessageStream = StreamController<SyncMessage>.broadcast();
var wsMessageStream = _wsMessageStream.stream;

class SyncMessage {
  final String method;
  final String uuid;
  final Map args;

  SyncMessage(this.method, this.uuid, this.args);

  SyncMessage.fromJson(Map<String, dynamic> json)
      : method = json["method"],
        uuid = json["uuid"],
        args = json["args"];

  Map toJson() {
    return {
      "method": method,
      "uuid": uuid,
      "args": args
    };
  }
}

void _handleWebSocket(WebSocket client) {
  print("New WebSocket client connected");
  _activeSocket?.close();
  _activeSocket = client;
  canSync.value = true;
  client.listen(_onClientData);
  client.done
    .then((_) => _onClientDone())
    .catchError((e) {
      print("Error in WebSocket client: $e");
      _onClientDone();
    });
  wsSend(SyncMessage("connected", "", {}));
  messageLog.add("Connected to Blender");
}

void _onClientData(data) {
  var message = SyncMessage.fromJson(jsonDecode(data));
  _wsMessageStream.add(message);
}

void _onClientDone() {
  print("WebSocket client disconnected");
  _activeSocket = null;
  canSync.value = false;
  messageLog.add("Disconnected from Blender");
}

void wsSend(SyncMessage data) {
  _activeSocket?.add(jsonEncode(data.toJson()));
}

void startSyncServer() async {
  final server = await HttpServer.bind("localhost", _wsPort);
  server.transform(WebSocketTransformer()).listen(_handleWebSocket);
}
