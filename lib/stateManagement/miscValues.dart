
import 'package:flutter/material.dart';


final windowTitle = ValueNotifier<String>("Nier Scripts Editor");

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
