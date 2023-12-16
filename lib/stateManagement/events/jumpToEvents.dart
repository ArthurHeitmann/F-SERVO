
import 'dart:async';

import '../openFiles/openFileTypes.dart';

class JumpToEvent {
  final OpenFileData file;

  const JumpToEvent(this.file);
}

class JumpToLineEvent extends JumpToEvent {
  final int line;

  const JumpToLineEvent(super.file, this.line);
}

class JumpToIdEvent extends JumpToEvent {
  final int id;
  final int? fallbackId;

  const JumpToIdEvent(super.file, this.id, [this.fallbackId]);
}

final jumpToStream = StreamController<JumpToEvent>.broadcast();
final jumpToEvents = jumpToStream.stream;
