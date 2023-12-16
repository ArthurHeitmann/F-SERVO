
import 'package:flutter/material.dart';

import '../utils/Disposable.dart';
import '../utils/utils.dart';
import 'hasUuid.dart';
import 'miscValues.dart';

mixin Undoable on HasUuid {
  Undoable takeSnapshot();
  void restoreWith(Undoable snapshot);
}

mixin HasUndoHistory on Undoable, Disposable {
  final List<Undoable> _undoStack = [];
  final ChangeNotifier historyNotifier = ChangeNotifier();
  int _undoIndex = 0;
  static bool _isPushing = false;
  static bool _isRestoring = false;
  bool get isPushing => _isPushing;
  bool get isRestoring => _isRestoring;
  late final void Function() _pushSnapshotThrottled;
  bool _isDisposed = false;

  initUndoHistory() {
    _pushSnapshotThrottled =  debounce(_pushSnapshot, 450);
  }

  void onUndoableEvent({ immediate = false }) {
    if (_isPushing) return;
    if (_isRestoring) return;
    if (_isDisposed) return;
    if (disableFileChanges) return;
    if (immediate)
      _pushSnapshot();
    else
      _pushSnapshotThrottled();
  }
  
  void _pushSnapshot() {
    if (_isRestoring) return;
    if (_isDisposed) return;
    _isPushing = true;
    try {
      if (_undoStack.length - 1 > _undoIndex) {
        for (int i = _undoStack.length - 1; i > _undoIndex; i--) {
          var item = _undoStack.removeAt(i);
          if (item is Disposable)
            (item as Disposable).dispose();
          else if (item is ChangeNotifier)
            (item as ChangeNotifier).dispose();
        }
      }
      int t1 = DateTime
        .now()
        .millisecondsSinceEpoch;
      _undoStack.add(takeSnapshot());
      _undoIndex = clamp(_undoIndex + 1, 0, _undoStack.length - 1);

      historyNotifier.notifyListeners();

      int tD = DateTime
        .now()
        .millisecondsSinceEpoch - t1;
      if (tD > 4)
        print("WARNING: Pushing history snapshot took ${tD}ms");
    } finally {
      _isPushing = false;
    }
  }

  void undo() {
    if (_undoStack.isEmpty || _undoIndex == 0)
      return;
    _undoIndex--;
    _isRestoring = true;
    try {
      restoreWith(_undoStack[_undoIndex]);
    } finally {
      _isRestoring = false;
      historyNotifier.notifyListeners();
    }
  }

  void redo() {
    if (_undoStack.isEmpty || _undoIndex == _undoStack.length - 1)
      return;
    _undoIndex++;
    _isRestoring = true;
    try {
      restoreWith(_undoStack[_undoIndex]);
    } finally {
      _isRestoring = false;
      historyNotifier.notifyListeners();
    }
  }

  bool get canUndo {
    return _undoStack.length > 1 && _undoIndex > 0;
  }

  bool get canRedo {
    return _undoStack.length > 1 && _undoIndex < _undoStack.length - 1;
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (var item in _undoStack) {
      if (item is Disposable)
        (item as Disposable).dispose();
      else if (item is ChangeNotifier)
        (item as ChangeNotifier).dispose();
    }
    _undoStack.clear();
    historyNotifier.dispose();
  }
}
