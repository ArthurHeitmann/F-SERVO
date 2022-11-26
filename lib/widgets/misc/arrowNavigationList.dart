
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../keyboardEvents/BetterShortcuts.dart';
import 'SelectableListEntry.dart';

mixin ArrowNavigationList<T extends StatefulWidget> on State<T> {
  int focusedIndex = 0;

  int get itemCount;

  void moveFocus(int delta) {
    var resultsLength = itemCount;
    focusedIndex = focusedIndex + delta;
    if (focusedIndex < -1)
      focusedIndex = resultsLength - 1;
    else if (focusedIndex >= resultsLength)
      focusedIndex = 0;
    setState(() { });
  }

  void selectFocused();

  Widget setupShortcuts({ required Widget child }) {
    return BetterShortcuts(
      shortcuts: {
        const KeyCombo(LogicalKeyboardKey.arrowUp, {}, true): ListEntryFocusChangeIntent(-1, moveFocus),
        const KeyCombo(LogicalKeyboardKey.arrowDown, {}, true): ListEntryFocusChangeIntent(1, moveFocus),
        const KeyCombo(LogicalKeyboardKey.enter): ListEntrySubmitIntent(selectFocused),
      },
      actions: {
        ListEntryFocusChangeIntent: ListEntryFocusChangeAction(),
        ListEntrySubmitIntent: ListEntrySubmitAction(),
      },
      child: child,
    );
  }
}
