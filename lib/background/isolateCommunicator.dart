
import 'dart:async';
import 'dart:isolate';

import '../utils.dart';
import 'IdsIndexer.dart';
import 'Initializable.dart';
import 'IndexingGroup.dart';

// class _IsolateCommunicatorPrivate is a background worker isolate 
// class IsolateCommunicator is a wrapper for usage from the main isolate

enum CommandTypes {
  setupSendPort,
  response,
  addIndexingPaths,
  removeIndexingPaths,
  clearIndexingPaths,
  lookupId,
}

Map _makeMessage(CommandTypes command, Map data, { String? uuid }) {
  return {
    "command": command.index,
    "uuid": uuid ?? uuidGen.v1(),
    ...data,
  };
}

void _sendMessage(SendPort sendPort, CommandTypes command, Map data, { String? uuid }) {
  sendPort.send(_makeMessage(command, data, uuid: uuid));
}

Future<Map> _sendMessageWithCompleter(SendPort sendPort, CommandTypes command, Map data, Map<String, Completer> completerMap) async {
  var uuid = uuidGen.v1();
  var completer = Completer<Map>();
  completerMap[uuid] = completer;
  _sendMessage(sendPort, command, data, uuid: uuid);
  return completer.future;
}

/// Separate isolate background worker
class _IsolateCommunicatorPrivate {
  final ReceivePort _receivePort = ReceivePort();
  final SendPort _sendPort;
  final IndexingGroup _indexingGroup = IndexingGroup();

  _IsolateCommunicatorPrivate(this._sendPort) {
    _receivePort.listen(handleMessage);
    _sendPort.send(_makeMessage(
      CommandTypes.setupSendPort,
      { "sendPort": _receivePort.sendPort, }
    ));
  }

  static entryPoint(SendPort sendPort) {
    _IsolateCommunicatorPrivate(sendPort);
  }

  void handleMessage(dynamic message) {
    CommandTypes command = CommandTypes.values[message["command"]];
    String uuid = message["uuid"];
    switch (command) {
      case CommandTypes.addIndexingPaths:
        addIndexingPaths(message["paths"], uuid);
        break;
      case CommandTypes.removeIndexingPaths:
        removeIndexingPaths(message["paths"], uuid);
        break;
      case CommandTypes.clearIndexingPaths:
        clearIndexingPaths(uuid);
        break;
      case CommandTypes.lookupId:
        lookupId(message["id"], uuid);
        break;
      default:
        print("Unhandled command: $command");
    }
  }

  void addIndexingPaths(List<String> paths, String uuid) async {
    await _indexingGroup.addPaths(paths);
    _sendMessage(
      _sendPort,
      CommandTypes.response,
      {  },
      uuid: uuid,
    );
  }

  void removeIndexingPaths(List<String> paths, String uuid) async {
    _indexingGroup.removePaths(paths);
    _sendMessage(
      _sendPort,
      CommandTypes.response,
      {  },
      uuid: uuid,
    );
  }

  void clearIndexingPaths(String uuid) async {
    _indexingGroup.clearPaths();
    _sendMessage(
      _sendPort,
      CommandTypes.response,
      {  },
      uuid: uuid,
    );
  }

  Future<void> lookupId(int id, String uuid) async {
    var data = await _indexingGroup.lookupId(id);
    _sendMessage(
      _sendPort,
      CommandTypes.response,
      { "data": data, },
      uuid: uuid,
    );
  }
}

/// For communication with the background worker
class IsolateCommunicator with Initializable {
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _sendPort;
  final Map<String, Completer> _awaitingResponses = {};

  IsolateCommunicator() {
    _receivePort.listen(handleMessage);
    Isolate.spawn(_IsolateCommunicatorPrivate.entryPoint, _receivePort.sendPort);
  }

  void handleMessage(dynamic message) {
    CommandTypes command = CommandTypes.values[message["command"]];
    String uuid = message["uuid"];
    switch (command) {
      case CommandTypes.setupSendPort:
        _sendPort = message["sendPort"];
        completeInitialization();
        break;
      case CommandTypes.response:
        if (_awaitingResponses.containsKey(uuid)) {
          _awaitingResponses[uuid]!.complete(message);
          _awaitingResponses.remove(uuid);
        } else {
          print("Unhandled command: $command");
        }
        break;
      default:
        print("Unhandled command: $command");
    }
  }

  Future<IndexedIdData?> lookupId(int id) async {
    await awaitInitialized();
    var response = await _sendMessageWithCompleter(
      _sendPort!,
      CommandTypes.lookupId,
      { "id": id, },
      _awaitingResponses,
    );
    return response["data"];
  }

  Future<void> addIndexingPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    await awaitInitialized();
    await _sendMessageWithCompleter(
      _sendPort!,
      CommandTypes.addIndexingPaths,
      { "paths": paths, },
      _awaitingResponses,
    );
  }

  Future<void> removeIndexingPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    await awaitInitialized();
    await _sendMessageWithCompleter(
      _sendPort!,
      CommandTypes.removeIndexingPaths,
      { "paths": paths, },
      _awaitingResponses,
    );
  }

  Future<void> clearIndexingPaths() async {
    await awaitInitialized();
    await _sendMessageWithCompleter(
      _sendPort!,
      CommandTypes.clearIndexingPaths,
      {  },
      _awaitingResponses,
    );
  }
}
