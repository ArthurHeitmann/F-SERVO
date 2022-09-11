
import 'dart:collection';

import 'package:flutter/material.dart';

import '../fileTypeUtils/yax/hashToStringMap.dart';

enum PropType {
  int, hexInt, double, vector, string
}

bool _isInt(String str) {
  return int.tryParse(str) != null;
}

bool _isHexInt(String str) {
  return str.startsWith("0x") && int.tryParse(str, radix: 16) != null;
}

bool _isDouble(String str) {
  return double.tryParse(str) != null;
}

bool _isVector(String str) {
 return str.split(" ").every((val) => _isDouble(val));
}

mixin Prop<T> implements Listenable {
  abstract final PropType type;

  static Prop fromString(String str) {
    if (_isInt(str))
      return IntProp(int.parse(str));
    else if (_isHexInt(str))
      return HexProp(int.parse(str, radix: 16));
    else if (_isDouble(str))
      return DoubleProp(double.parse(str));
    else if (_isVector(str))
      return VectorProp(str.split(" ").map((val) => double.parse(val)).toList());
    else
      return StringProp(str);
  }
}

abstract class ValueProp<T> extends ValueNotifier<T> with Prop<T> {
  ValueProp(super.value);
}

class IntProp extends ValueProp<int> {
  @override
  final PropType type = PropType.int;

  IntProp(super.value);
}

class HexProp extends ValueProp<int> {
  @override
  final PropType type = PropType.hexInt;

  String? _strVal;

  HexProp(super.value) : _strVal = hashToStringMap[value];

  String? get strVal => _strVal;

  bool get isHashed => _strVal != null;

  @override
  set value(value) {
    super.value = value;
    _strVal = hashToStringMap[value];
  }

  @override
  String toString() => "0x${value.toRadixString(16)}";
}

class DoubleProp extends ValueProp<double> {
  @override
  final PropType type = PropType.double;

  DoubleProp(super.value);
}

class VectorProp extends ChangeNotifier with Prop<List<double>>, IterableMixin<double> {
  @override
  final PropType type = PropType.vector;
  late final List<double> _values;

  VectorProp(List<double> values) : _values = List<double>.from(values);
  
  @override
  Iterator<double> get iterator => _values.iterator;

  @override
  int get length => _values.length;

  double operator [](int index) => _values[index];

  void operator []=(int index, double value) {
    _values[index] = value;
    notifyListeners();
  }

  @override
  String toString() => _values.join(" ");
}

class StringProp extends ValueProp<String> {
  @override
  final PropType type = PropType.string;

  StringProp(super.value);
}
