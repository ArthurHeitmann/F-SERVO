
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

class AutoTranslateValueNotifier extends ValueNotifier<bool> {
  AutoTranslateValueNotifier(super.value);
  
  @override
  set value(bool newValue) {
    disableFileChanges = true;
    super.value = newValue;
    disableFileChanges = false;
  }
}

final shouldAutoTranslate = AutoTranslateValueNotifier(true);
