
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:window_manager/window_manager.dart';

import '../stateManagement/events/statusInfo.dart';
import '../stateManagement/hierarchy/FileHierarchy.dart';
import '../stateManagement/openFiles/openFilesManager.dart';
import '../stateManagement/openFiles/types/xml/sync/syncServer.dart';
import 'utils.dart';

void onFileOpenCommand(List<String> paths) async {
  await Future.wait(paths.map((path) async {
    await openHierarchyManager.openFile(path);
    if (await canOpenAsFile(path))
      areasManager.openFile(path);
  }));
  await windowManager.focus();
  messageLog.add("");
}

Future<bool> trySendFileArgs(List<String> args) async {
  if (args.isEmpty)
    return false;
  var completer = Completer<bool>();
  WebSocket? webSocket;
  var timeout = Timer(const Duration(milliseconds: 500), () {
    completer.complete(false);
    webSocket?.close();
  });
  unawaited(WebSocket.connect("ws://localhost:$wsPort")
    .then((ws) {
      if (completer.isCompleted) {
        ws.close();
        return;
      }
      webSocket = ws;
      ws.add(jsonEncode(CustomWsMessage("openFiles", {"files": args})));
      ws.listen((data) {
        var msg = SyncMessage.fromJson(jsonDecode(data));
        if (msg.method == "connected") {
          completer.complete(true);
          ws.close();
          timeout.cancel();
        }
      });
    })
    .catchError((e) {
      completer.complete(false);
    })
  );

  return completer.future;
}
