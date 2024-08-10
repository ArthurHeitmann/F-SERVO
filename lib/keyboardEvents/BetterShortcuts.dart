
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/utils.dart';

class KeyCombo {
  final LogicalKeyboardKey key;
  final Set<ModifierKey> modifiers;
  final bool allowRepeat;

  const KeyCombo(this.key, [this.modifiers = const <ModifierKey>{}, this.allowRepeat = false]);

  @override
  String toString() {
    return "KeyCombo{key: ${key.debugName}, modifiers: $modifiers}";
  }
}

class ManualKeyEvent {
  final LogicalKeyboardKey key;
  final Set<ModifierKey> modifiers;

  ManualKeyEvent(this.key, {bool ctrl = false, bool alt = false, bool shift = false, bool meta = false})
    : modifiers = {
      if (ctrl)
        ModifierKey.controlModifier,
      if (alt)
        ModifierKey.altModifier,
      if (shift)
        ModifierKey.shiftModifier,
      if (meta)
        ModifierKey.metaModifier,
    };
}

class BetterShortcuts extends StatefulWidget {
  static final StreamController<ManualKeyEvent> _manualKeyEvents = StreamController.broadcast();
  final Map<KeyCombo, Intent> shortcuts;
  final Map<Type, Action<Intent>> actions;
  final Widget child;

  const BetterShortcuts({ super.key, required this.shortcuts, required this.actions, required this.child });

  @override
  State<BetterShortcuts> createState() => _BetterShortcutsState();

  static void sendKeyEvent(ManualKeyEvent event) {
    _manualKeyEvents.add(event);
  }
}

class _BetterShortcutsState extends State<BetterShortcuts> {
  KeyDataCallback? prevKeyDataCallback;
  late StreamSubscription<ManualKeyEvent> _manualKeyEventSubscription;

  @override
  void initState() {
    prevKeyDataCallback = window.onKeyData;
    HardwareKeyboard.instance.addHandler(onKey);
    _manualKeyEventSubscription = BetterShortcuts._manualKeyEvents.stream.listen(onManualKeyEvent);
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(onKey);
    _manualKeyEventSubscription.cancel();
    super.dispose();
  }

  bool onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return false;

    var pressedModifiers = {
      if (isShiftPressed())
        ModifierKey.shiftModifier,
      if (isCtrlPressed())
        ModifierKey.controlModifier,
      if (isAltPressed())
        ModifierKey.altModifier,
      if (isMetaPressed())
        ModifierKey.metaModifier,
    };

    for (var shortcut in widget.shortcuts.entries) {
      if (_matches(shortcut.key, pressedModifiers) && (shortcut.key.allowRepeat || event is! KeyRepeatEvent)) {
        final action = widget.actions[shortcut.value.runtimeType];
        if (action != null) {
          // ignore: invalid_use_of_protected_member
          action.invoke(shortcut.value);
          return true;
        }
      }
    }
    
    return false;
  }

  void onManualKeyEvent(ManualKeyEvent event) {
    for (var shortcut in widget.shortcuts.entries) {
      if (_matchesManual(shortcut.key, event)) {
        final action = widget.actions[shortcut.value.runtimeType];
        if (action != null) {
          // ignore: invalid_use_of_protected_member
          action.invoke(shortcut.value);
          return;
        }
      }
    }
  }

  bool _matches(KeyCombo keyCombo, Set<ModifierKey> pressedModifiers) {
    if (pressedModifiers.length != keyCombo.modifiers.length)
      return false;
    if (!pressedModifiers.containsAll(keyCombo.modifiers))
      return false;
    return HardwareKeyboard.instance.logicalKeysPressed.contains(keyCombo.key);
  }

  bool _matchesManual(KeyCombo keyCombo, ManualKeyEvent event) {
    if (event.modifiers.length != keyCombo.modifiers.length)
      return false;
    if (!event.modifiers.containsAll(keyCombo.modifiers))
      return false;
    return event.key == keyCombo.key;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
