import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../utils/utils.dart';
import 'hasUuid.dart';
import 'undoable.dart';

abstract class IterableNotifier<T> extends ChangeNotifier with IterableMixin<T>, HasUuid, Undoable {
  final List<T> _children;
  late final ChangeNotifier onDisposed;
  bool _debugDisposed = false;

  IterableNotifier(List<T> children)
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

  @override
  void dispose() {
    assert(() {
      if (_debugDisposed) {
        throw FlutterError(
            "A $runtimeType was used after being disposed.\n"
                "Once you have called dispose() on a $runtimeType, it can no longer be used."
        );
      }
      _debugDisposed = true;
      return true;
    }());
    for (var child in _children) {
      if (child is ChangeNotifier)
        child.dispose();
    }
    super.dispose();
    onDisposed.notifyListeners();
    onDisposed.dispose();
  }
}
abstract class ListNotifier<T> extends IterableNotifier<T> {

  ListNotifier(List<T> children) : super(children);

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
    if (from == to)
      return;
    if (from < 0 || from >= _children.length || to < 0 || to >= _children.length)
      throw RangeError('from: $from, to: $to, length: ${_children.length}');
    var child = _children.removeAt(from);
    _children.insert(to, child);
    notifyListeners();
  }

  void clear() {
    if (_children.isEmpty) return;
    _children.clear();
    notifyListeners();
  }

  void sort([int Function(T, T)? compare]) {
    if (_children.length < 2)
      return;
    _children.sort(compare);
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
    var curUuids = _children.map((e) => (e as HasUuid).uuid).toList();
    var newUuids = newChildren.map((e) => e.uuid).toList();
    var curUuidsSet = curUuids.toSet();
    var newUuidsSet = newUuids.toSet();
    var sameUuids = curUuidsSet.intersection(newUuidsSet);
    // var removedUuids = curUuidsSet.difference(sameUuids);
    if (curUuidsSet.length != _children.length) {
      print("WARNING: ${(curUuids.length - _children.length).abs()} duplicate uuids in children");
    }

    List<T> nextChildren;
    if (listEquals(curUuids, newUuids)) {
      nextChildren = _children;
    } else {
      nextChildren = newUuids.map((uuid) {
        if (sameUuids.contains(uuid))
          return _children[curUuids.indexOf(uuid)];
        else
          return copy(newChildren[newUuids.indexOf(uuid)]);
      }).toList();
    }

    for (var uuid in sameUuids) {
      var childI = curUuids.indexOf(uuid);
      var child = _children[childI];
      var newChildI = newUuids.indexOf(uuid);
      var newChild = newChildren[newChildI];
      if (child.runtimeType == newChild.runtimeType && child is Undoable)
        child.restoreWith(newChild);
      else
        nextChildren[newChildI] = copy(newChild);
    }

    // for (var uuid in removedUuids) {
    //   var childI = curUuids.indexOf(uuid);
    //   var child = _children[childI];
    //   if (child is ChangeNotifier)
    //     child.dispose();
    // }

    replaceWith(nextChildren);
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
}

class ValueListNotifier<T> extends ListNotifier<T> {
  ValueListNotifier(super.children);

  @override
  Undoable takeSnapshot() {
    Undoable snapshot;
    if (isSubtype<T, Undoable>())
      snapshot = ValueListNotifier(_children.map((e) => (e as Undoable).takeSnapshot() as T).toList());
    else
      snapshot = ValueListNotifier<T>(toList());
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var list = snapshot as ValueListNotifier<T>;
    if (isSubtype<T, Undoable>()) {
      updateOrReplaceWith(list.toList() as List<Undoable>, (e) => e.takeSnapshot() as T);
    }
    else {
      replaceWith(list._children);
    }
  }
}
