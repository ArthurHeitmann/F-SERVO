
import 'dart:collection';

import 'package:flutter/material.dart';

import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../utils.dart';

enum PropType {
  int, hexInt, double, vector, string
}

mixin Prop<T> implements Listenable {
  abstract final PropType type;

  void updateWith(String str);

  static Prop fromString(String str) {
    if (isInt(str))
      return IntProp(int.parse(str));
    else if (isHexInt(str))
      return HexProp(int.parse(str, radix: 16));
    else if (isDouble(str))
      return DoubleProp(double.parse(str));
    else if (isVector(str))
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
  
  @override
  void updateWith(String str) {
    value = int.parse(str);
  }
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
  
  @override
  void updateWith(String str, { bool isStr = false }) {
    if (isStr) {
      value = crc32(str);
      _strVal = str;
    }
    else {
      value = int.parse(str.substring(2), radix: 16);
    }
  }
}

class DoubleProp extends ValueProp<double> {
  @override
  final PropType type = PropType.double;

  DoubleProp(super.value);
  
  @override
  void updateWith(String str) {
    value = double.parse(str);
  }
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
  
  @override
  void updateWith(String str) {
    _values = str.split(" ").map((val) => double.parse(val)).toList();
    notifyListeners();
  }
}

class StringProp extends ValueProp<String> {
  @override
  final PropType type = PropType.string;
  
  String Function(String) transform = (str) => str;

  StringProp(super.value);
  
  @override
  void updateWith(String str) {
    value = str;
  }

  @override
  String toString() => transform(value);
}
