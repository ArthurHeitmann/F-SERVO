
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/utils.dart';
import '../widgets/misc/TextFieldFocusNode.dart';
import 'BetterShortcuts.dart';
import 'actions.dart';
import 'intents.dart';

Widget globalShortcutsWrapper(BuildContext context, { required Widget child }) {
  return BetterShortcuts(
    shortcuts: const {
      KeyCombo(LogicalKeyboardKey.tab, {ModifierKey.controlModifier}):
        TabChangeIntent(HorizontalDirection.right),
      KeyCombo(LogicalKeyboardKey.tab, {ModifierKey.controlModifier, ModifierKey.shiftModifier}):
        TabChangeIntent(HorizontalDirection.left),
      KeyCombo(LogicalKeyboardKey.keyW, {ModifierKey.controlModifier}):
        CloseTabIntent(),
      KeyCombo(LogicalKeyboardKey.keyS, {ModifierKey.controlModifier}):
        SaveTabIntent(),
      KeyCombo(LogicalKeyboardKey.keyZ, {ModifierKey.controlModifier}):
        UndoIntent(),
      KeyCombo(LogicalKeyboardKey.keyY, {ModifierKey.controlModifier}):
        RedoIntent(),
      KeyCombo(LogicalKeyboardKey.keyC, {ModifierKey.controlModifier}):
        ChildKeyboardActionIntent(ChildKeyboardActionType.copy),
      KeyCombo(LogicalKeyboardKey.keyX, {ModifierKey.controlModifier}):
        ChildKeyboardActionIntent(ChildKeyboardActionType.cut),
      KeyCombo(LogicalKeyboardKey.keyV, {ModifierKey.controlModifier}):
        ChildKeyboardActionIntent(ChildKeyboardActionType.paste),
      KeyCombo(LogicalKeyboardKey.delete):
        ChildKeyboardActionIntent(ChildKeyboardActionType.delete),
      KeyCombo(LogicalKeyboardKey.keyD, {ModifierKey.controlModifier}):
        ChildKeyboardActionIntent(ChildKeyboardActionType.duplicate),
    },
    actions: {
      TabChangeIntent: TabChangeAction(),
      CloseTabIntent: CloseTabAction(),
      SaveTabIntent: SaveTabAction(),
      UndoIntent: UndoAction(),
      RedoIntent: RedoAction(),
      ChildKeyboardActionIntent: ChildKeyboardAction(),
    },
    // child: _arrowKeyEventsSuppressor(context, child: child),
    child: child,
  );
}

Widget _arrowKeyEventsSuppressor(BuildContext context, { required Widget child }) {
  return Focus(
    onKey: (node, event) {
      if (event is! RawKeyDownEvent)
        return KeyEventResult.ignored;
      final arrowKeys = {
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
      };
      bool isArrowKey = arrowKeys.contains(event.logicalKey);
      bool isTextFieldFocused = FocusScope.of(context).focusedChild is! TextFieldFocusNode;
      if (isArrowKey && isTextFieldFocused) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}
