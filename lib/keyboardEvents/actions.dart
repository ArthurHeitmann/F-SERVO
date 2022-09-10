
import 'package:flutter/material.dart';

import '../stateManagement/openFilesManager.dart';
import '../utils.dart';
import 'intents.dart';

class TabChangeAction extends Action<TabChangeIntent> {
  TabChangeAction();

  @override
  void invoke(TabChangeIntent intent) {
    if (intent.direction == HorizontalDirection.right)
      areasManager.activeArea?.switchToNextFile();
    else
      areasManager.activeArea?.switchToPreviousFile();
  }
}

class CloseTabAction extends Action<CloseTabIntent> {
  CloseTabAction();

  @override
  void invoke(CloseTabIntent intent) {
    if (areasManager.activeArea?.currentFile != null)
      areasManager.activeArea?.closeFile(areasManager.activeArea!.currentFile!);
  }
}

class SaveTabAction extends Action<SaveTabIntent> {
  SaveTabAction();

  @override
  void invoke(SaveTabIntent intent) {
    if (areasManager.activeArea?.currentFile != null)
      print("Saving not implemented yet");
  }
}
