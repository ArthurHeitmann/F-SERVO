import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../utils/utils.dart';
import 'hasUuid.dart';
import 'undoable.dart';

abstract class NestedNotifier<T> extends ChangeNotifier with IterableMixin<T>, HasUuid, Undoable {
  final List<T> _children;
  late final ChangeNotifier onDisposed;

  NestedNotifier(List<T> children)
    : _children = children,
    onDisposed = ChangeNotifier();
    
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

  int indexWhere(bool Function(T) test) => _children.indexWhere(test);

  T? find(bool Function(T) test) {
    for (final child in _children) {
      if (test(child))
        return child;
    }
    return null;
  }

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

  T removeAt(int index) {
    var ret =_children.removeAt(index);
    notifyListeners();
    return ret;
  }

  void removeWhere(bool Function(T) test) {
    _children.removeWhere(test);
    notifyListeners();
  }

  void move(int from, int to) {
    if (from == to) return;
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
    if (isSubtype<T, HasUuid>())
      updateOrReplaceWithUuid(newChildren, copy);
    else
      updateOrReplaceWithIndex(newChildren, copy);
  }

  void updateOrReplaceWithUuid(List<Undoable> newChildren, T Function(Undoable) copy) {
    bool hasChanged = false;

    // use uuid comparison instead
    var curUuids = _children.map((e) => (e as HasUuid).uuid).toSet();
    if (curUuids.length != _children.length) {
      print("WARNING: ${(curUuids.length - _children.length).abs()} duplicate uuids in children");
    }
    var newUuids = newChildren.map((e) => e.uuid).toSet();
    var sameUuids = curUuids.intersection(newUuids);
    var addedUuids = newUuids.difference(sameUuids);
    var removedUuids = curUuids.difference(sameUuids);

    var addedChildren = newChildren.where((e) => addedUuids.contains(e.uuid)).map(copy).toList();
    var removedChildren = _children.where((e) => removedUuids.contains((e as HasUuid).uuid)).toList();
    var sameChildren = _children.where((e) => sameUuids.contains((e as HasUuid).uuid)).toList();

    for (int i = 0; i < sameChildren.length; i++) {
      if (sameChildren[i].runtimeType == newChildren[i].runtimeType && sameChildren[i] is Undoable) {
        (sameChildren[i] as Undoable).restoreWith(newChildren[i]);
        hasChanged = true;
      }
      else {
        sameChildren[i] = copy(newChildren[i]);
        hasChanged = true;
      }
    }
    if (addedChildren.isNotEmpty) {
      _children.addAll(addedChildren);
      hasChanged = true;
    }
    if (removedChildren.isNotEmpty) {
      _children.removeWhere((e) => removedChildren.contains(e));
      hasChanged = true;
    }

    if (hasChanged)
      notifyListeners();
  }

  void updateOrReplaceWithIndex(List<Undoable> newChildren, T Function(Undoable) copy) {
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
    onDisposed.notifyListeners();
  }
}

class ValueNestedNotifier<T> extends NestedNotifier<T> {
  
  ValueNestedNotifier(super.children);

  @override
  Undoable takeSnapshot() {
    if (isSubtype<T, Undoable>())
      return ValueNestedNotifier(_children.map((e) => (e as Undoable).takeSnapshot() as T).toList());
    else
      return ValueNestedNotifier<T>(toList());
  }

  @override
  void restoreWith(Undoable snapshot) {
    var list = snapshot as ValueNestedNotifier<T>;
    if (T is Undoable) {
      updateOrReplaceWith(list.toList() as List<Undoable>, (e) => e.takeSnapshot() as T);
    }
    else {
      replaceWith(list._children);
    }
  }
}
