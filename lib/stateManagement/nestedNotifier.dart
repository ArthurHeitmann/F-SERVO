import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'hasUuid.dart';
import 'undoable.dart';

abstract class NestedNotifier<T> extends ChangeNotifier with IterableMixin<T>, Undoable, HasUuid {
  final List<T> _children;

  NestedNotifier(List<T> children)
    : _children = children;
    
  @override
  Iterator<T> get iterator => _children.iterator;

  @override
  int get length => _children.length;

  T operator [](int index) => _children[index];

  void operator []=(int index, T value) {
    if (value == _children[index]) return;
    _children[index] = value;
    notifyListeners();
  }

  int indexOf(T child) => _children.indexOf(child);

  T? findRecWhere(bool Function(T) test, { Iterable<T>? children }) {
    children ??= this;
    for (var child in children) {
      if (test(child))
        return child;
      if (child is! Iterable)
        continue;
      var result = findRecWhere(test, children: child as Iterable<T>);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  List<T> findAllRecWhere(bool Function(T) test, { Iterable<T>? children }) {
    children ??= this;
    var result = <T>[];
    for (var child in children) {
      if (test(child))
        result.add(child);
      if (child is! Iterable)
        continue;
      result.addAll(findAllRecWhere(test, children: child as Iterable<T>));
    }
    return result;
  }

  void add(T child) {
    _children.add(child);
    notifyListeners();
  }

  void addAll(Iterable<T> children) {
    if (children.isEmpty) return;
    _children.addAll(children);
    notifyListeners();
  }

  void insert(int index, T child) {
    _children.insert(index, child);
    notifyListeners();
  }

  void remove(T child) {
    _children.remove(child);
    notifyListeners();
  }

  void removeAt(int index) {
    _children.removeAt(index);
    notifyListeners();
  }

  void move(int from, int to) {
    if (from == to) return;
    if (to > from)
      to--;
    var child = _children.removeAt(from);
    _children.insert(to, child);
    notifyListeners();
  }

  void clear() {
    if (_children.isEmpty) return;
    _children.clear();
    notifyListeners();
  }

  void replaceWith(List<T> newChildren) {
    if (listEquals(newChildren, _children)) return;
    _children.clear();
    _children.addAll(newChildren);
    notifyListeners();
  }

  void updateOrReplaceWith(List<Undoable> newChildren, T Function(Undoable) copy) {
    bool hasChanged = false;
    // try to update same type children first
    for (int i = 0; i < min(_children.length, newChildren.length); i++) {
      if (_children[i].runtimeType == newChildren[i].runtimeType && _children[i] is Undoable) {
        (_children[i] as Undoable).restoreWith(newChildren[i]);
        hasChanged = true;
      }
      else {
        _children[i] = copy(newChildren[i]);
        hasChanged = true;
      }
    }
    // add new children
    if (_children.length < newChildren.length) {
      _children.addAll(
        newChildren.sublist(_children.length)
        .map(copy)
        .toList()
      );
      hasChanged = true;
    }
    // remove extra children
    else if (_children.length > newChildren.length) {
      _children.removeRange(newChildren.length, _children.length);
      hasChanged = true;
    }

    if (hasChanged)
      notifyListeners();
  }

  @override
  void dispose() {
    for (var child in _children) {
      if (child is ChangeNotifier)
        child.dispose();
    }
    super.dispose();
  }
}

class ValueNestedNotifier<T> extends NestedNotifier<T> {
  
  ValueNestedNotifier(super.children);

  @override
  Undoable takeSnapshot() {
    return ValueNestedNotifier<T>(toList());
  }

  @override
  void restoreWith(Undoable snapshot) {
    var snapshotCopy = snapshot as ValueNestedNotifier<T>;
    replaceWith(snapshotCopy._children);
  }
}
