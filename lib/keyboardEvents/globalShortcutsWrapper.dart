
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils.dart';
import 'actions.dart';
import 'intents.dart';

Widget globalShortcutsWrapper(BuildContext context, { required Widget child }) {
  return Shortcuts(
    shortcuts: {
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab):
        TabChangeIntent(HorizontalDirection.right),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
        TabChangeIntent(HorizontalDirection.left),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW):
        CloseTabIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
        SaveTabIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
        UndoIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
        RedoIntent(),
    },
    child: Actions(
      actions: {
        TabChangeIntent: TabChangeAction(),
        CloseTabIntent: CloseTabAction(),
        SaveTabIntent: SaveTabAction(),
        UndoIntent: UndoAction(),
        RedoIntent:RedoAction(),
      },
      child: child
    )
  );
}
