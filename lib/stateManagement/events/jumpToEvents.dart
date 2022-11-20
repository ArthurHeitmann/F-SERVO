
import 'dart:async';

import '../openFileTypes.dart';

class JumpToEvent {
  final OpenFileData file;

  const JumpToEvent(this.file);
}

class JumpToLineEvent extends JumpToEvent {
  final int line;

  const JumpToLineEvent(OpenFileData file, this.line) : super(file);
}

class JumpToIdEvent extends JumpToEvent {
  final int id;
  final int? fallbackId;

  const JumpToIdEvent(OpenFileData file, this.id, [this.fallbackId]) : super(file);
}

final jumpToStream = StreamController<JumpToEvent>.broadcast();
final jumpToEvents = jumpToStream.stream;
