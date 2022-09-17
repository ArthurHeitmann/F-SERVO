
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../utils.dart';
import 'miscValues.dart';
import 'undoable.dart';

enum PropType {
  int, hexInt, double, vector, string
}

mixin Prop<T> implements Listenable, Undoable {
  abstract final PropType type;

  void updateWith(String str);

  static Prop fromString(String str) {
    if (isHexInt(str))
      return HexProp(int.parse(str));
    else if (isInt(str))
      return IntProp(int.parse(str));
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

  @override
  void restoreWith(Undoable snapshot) {
    value = (snapshot as ValueProp).value;
  }

  @override
  set value(T value) {
    if (value == this.value) return;
    super.value = value;
    undoHistoryManager.onUndoableEvent();
  }

  @override
  String toString() => value.toString();
}

class IntProp extends ValueProp<int> {
  @override
  final PropType type = PropType.int;

  IntProp(super.value);
  
  @override
  void updateWith(String str) {
    value = int.parse(str);
  }
  
  @override
  Undoable takeSnapshot() {
    return IntProp(value);
  }
}

class HexProp extends ValueProp<int> {
  @override
  final PropType type = PropType.hexInt;

  String? _strVal;

  HexProp(super.value) {
    _strVal = getReverseHash(value);
  }

  String? get strVal => _strVal;

  bool get isHashed => _strVal != null;

  String? getReverseHash(int hash) {
    return hash != 0 ? hashToStringMap[hash] : null;
  }

  @override
  set value(value) {
    _strVal = getReverseHash(value);
    super.value = value;
  }

  void setValueAndStr(int value, String? str) {
    _strVal = str;
    super.value = value;
  }

  @override
  String toString() => "0x${value.toRadixString(16)}";
  
  @override
  void updateWith(String str, { bool isStr = false }) {
    if (isStr) {
      int strHash = crc32(str);
      setValueAndStr(strHash, str);
    }
    else {
      value = int.parse(str);
    }
  }
  
  @override
  Undoable takeSnapshot() {
    var prop = HexProp(value);
    prop._strVal = _strVal;
    return prop;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var prop = snapshot as HexProp;
    setValueAndStr(prop.value, prop.strVal);
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

  @override
  Undoable takeSnapshot() {
    return DoubleProp(value);
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
    if (value == _values[index]) return;
    _values[index] = value;
    notifyListeners();
    undoHistoryManager.onUndoableEvent();
  }

  @override
  String toString() => _values.join(" ");
  
  @override
  void updateWith(String str) {
    _values = str.split(" ").map((val) => double.parse(val)).toList();
    notifyListeners();
    undoHistoryManager.onUndoableEvent();
  }

  @override
  Undoable takeSnapshot() {
    return VectorProp(_values);
  }

  @override
  void restoreWith(Undoable snapshot) {
    var prop = snapshot as VectorProp;
    if (listEquals(_values, prop._values)) return;
    _values = List<double>.from(prop._values);
    notifyListeners();
  }
}

class StringProp extends ValueProp<String> {
  @override
  final PropType type = PropType.string;
  
  String Function(String) transform = tryToTranslate;

  StringProp(super.value) {
    shouldAutoTranslate.addListener(notifyListeners);
  }

  @override
  void dispose() {
    shouldAutoTranslate.removeListener(notifyListeners);
    super.dispose();
  }
  
  @override
  void updateWith(String str) {
    value = str;
  }

  @override
  String toString() => transform(value);

  @override
  Undoable takeSnapshot() {
    return StringProp(value);
  }
}
