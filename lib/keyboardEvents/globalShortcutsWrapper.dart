
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils.dart';
import 'actions.dart';
import 'intents.dart';

Widget globalShortcutsWrapper(BuildContext context, { required Widget child }) {
  return Shortcuts(
    shortcuts: {
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab):
        const TabChangeIntent(HorizontalDirection.right),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
        const TabChangeIntent(HorizontalDirection.left),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW):
        const CloseTabIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
        const SaveTabIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
        const UndoIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
        const RedoIntent(),
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
