
import 'package:flutter/material.dart';

import '../utils.dart';
import 'FileHierarchy.dart';
import 'openFileContents.dart';
import 'openFilesManager.dart';

mixin Undoable {
  Undoable takeSnapshot();
  void restoreWith(Undoable snapshot);
}

class _UndoSnapshot {
  late final Undoable fileAreasSnapshot;
  late final Undoable fileContentsSnapshot;
  late final Undoable openHierarchySnapshot;

  _UndoSnapshot(this.fileAreasSnapshot, this.fileContentsSnapshot, this.openHierarchySnapshot);

  _UndoSnapshot.take() {
    fileAreasSnapshot = areasManager.takeSnapshot();
    fileContentsSnapshot = fileContentsManager.takeSnapshot();
    openHierarchySnapshot = openHierarchyManager.takeSnapshot();
  }

  void restore() {
    areasManager.restoreWith(fileAreasSnapshot);
    fileContentsManager.restoreWith(fileContentsSnapshot);
    openHierarchyManager.restoreWith(openHierarchySnapshot);
  }
}

class UndoHistoryManager with ChangeNotifier {
  final List<_UndoSnapshot> _undoStack = [];
  int _undoIndex = 0;
  bool _isRestoring = false;
  late final void Function() _pushSnapshotThrottled;

  UndoHistoryManager() {
    _pushSnapshotThrottled =  debounce(_pushSnapshot, 450);
    Future.delayed(Duration(milliseconds: 500), _pushSnapshot);
  }

  void onUndoableEvent() {
    if (_isRestoring) return;
    _pushSnapshotThrottled();
  }
  
  void _pushSnapshot() {
    if (_isRestoring) return;
    if (_undoStack.length - 1 > _undoIndex) {
      _undoStack.removeRange(_undoIndex + 1, _undoStack.length);
    }
    int t1 = DateTime.now().millisecondsSinceEpoch;
    _undoStack.add(_UndoSnapshot.take());
    int t2 = DateTime.now().millisecondsSinceEpoch;
    print("Pushing history snapshot took ${t2 - t1}ms");
    _undoIndex = clamp(_undoIndex + 1, 0, _undoStack.length - 1);
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty || _undoIndex == 0)
      return;
    _undoIndex--;
    _isRestoring = true;
    try {
      _undoStack[_undoIndex].restore();
    } finally {
      _isRestoring = false;
    }
    notifyListeners();
  }

  void redo() {
    if (_undoStack.isEmpty || _undoIndex == _undoStack.length - 1)
      return;
    _undoIndex++;
    _isRestoring = true;
    try {
      _undoStack[_undoIndex].restore();
    } finally {
      _isRestoring = false;
    }
    notifyListeners();
  }

  bool get canUndo {
    return _undoStack.length > 1 && _undoIndex > 0;
  }

  bool get canRedo {
    return _undoStack.length > 1 && _undoIndex < _undoStack.length - 1;
  }
}

final undoHistoryManager = UndoHistoryManager();
