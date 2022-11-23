
import 'dart:collection';

import 'package:flutter/material.dart';


const _windowTitleDefault = "Nier Scripts Editor";
class _WindowTitleVN extends ValueNotifier<String> {
  _WindowTitleVN() : super("");

  @override
  String get value => _windowTitleDefault + (super.value.isEmpty ? "" : "  |  ${super.value}");
}

final windowTitle = _WindowTitleVN();


/// ugly fix
bool disableFileChanges = false;

/// Optimized for A LOT of adding and removing of listeners
class AutoTranslateValueNotifier extends Listenable {
  final Set<VoidCallback> _listeners = HashSet<VoidCallback>();
  bool _value = false;

  AutoTranslateValueNotifier(this._value);

  bool get value => _value;
  
  set value(bool newValue) {
    if (newValue == _value)
      return;
    disableFileChanges = true;
    _value = newValue;
    notifyListeners();
    disableFileChanges = false;
  }

  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
  
  @override
  void addListener(VoidCallback listener) {
    if (_listeners.contains(listener))  // TODO remove after some time
      throw Exception("Listener already added");
    _listeners.add(listener);
  }
  
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

final shouldAutoTranslate = AutoTranslateValueNotifier(true);
