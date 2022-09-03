import 'dart:collection';
import 'package:flutter/material.dart';

import '../utils.dart';

class NestedNotifier<T> extends ChangeNotifier with IterableMixin<T> {
  final String uuid;
  final List<T> _children;

  NestedNotifier(List<T> children)
    : _children = children, uuid = uuidGen.v1();
    
  @override
  Iterator<T> get iterator => _children.iterator;

  @override
  int get length => _children.length;

  T operator [](int index) => _children[index];

  void operator []=(int index, T value) {
    _children[index] = value;
    notifyListeners();
  }

  int indexOf(T child) => _children.indexOf(child);

  void add(T child) {
    _children.add(child);
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
    if (to > from)
      to--;
    var child = _children.removeAt(from);
    _children.insert(to, child);
    notifyListeners();
  }

  void clear() {
    _children.clear();
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

abstract class ChangeNotifierWidget extends StatefulWidget {
  final ChangeNotifier notifier;
  
  const ChangeNotifierWidget({Key? key, required this.notifier}) : super(key: key);
}

abstract class ChangeNotifierState<T extends ChangeNotifierWidget> extends State<T> {
  void _onChange() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChange);
    super.dispose();
  }
}
