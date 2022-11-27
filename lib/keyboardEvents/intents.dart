
import 'package:flutter/material.dart';

import '../utils/utils.dart';

class TabChangeIntent extends Intent {
  final HorizontalDirection direction;
  const TabChangeIntent(this.direction);
}

class CloseTabIntent extends Intent {
  const CloseTabIntent();
}

class SaveTabIntent extends Intent {
  const SaveTabIntent();
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

enum ChildKeyboardActionType {
  copy,
  cut,
  paste,
  delete,
  duplicate,
}

class ChildKeyboardActionIntent extends Intent {
  final ChildKeyboardActionType action;
  const ChildKeyboardActionIntent(this.action);
}
