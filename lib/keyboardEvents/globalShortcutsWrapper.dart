
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../stateManagement/openFilesManager.dart';
import '../utils.dart';
import 'actions.dart';
import 'intents.dart';

Widget globalShortcutsWrapper({ required Widget child }) {
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
    },
    child: Actions(
      actions: {
        TabChangeIntent: TabChangeAction(),
        CloseTabIntent: CloseTabAction(),
        SaveTabIntent: SaveTabAction(),
      },
      child: child
    )
  );
}

class TestIntent extends Intent {
  const TestIntent();
}

class TestAction extends Action<TestIntent> {
  @override
  void invoke(Intent intent) {
    print('Beep Boop');
  }
}
