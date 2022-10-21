
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _wsPort = 1547;

WebSocket? _activeSocket;

var _wsMessageStream = StreamController<String>.broadcast();
var wsMessageStream = _wsMessageStream.stream;

void _handleWebSocket(WebSocket client) {
  print("New WebSocket client connected");
  _activeSocket?.close();
  _activeSocket = client;
  client.listen(_onClientData);
}

void _onClientData(data) {
  var message = jsonDecode(data);
  _wsMessageStream.add(message);
}

void wsSend(dynamic data) {
  _activeSocket?.add(jsonEncode(data));
}

void startSyncServer() async {
  final server = await HttpServer.bind("localhost", _wsPort);
  server.transform(WebSocketTransformer()).listen(_handleWebSocket);
}
