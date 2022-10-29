
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

class AutoTranslateValueNotifier extends Listenable {
  final List<VoidCallback> _listeners = [];
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
    _listeners.add(listener);
  }
  
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

final shouldAutoTranslate = AutoTranslateValueNotifier(true);
