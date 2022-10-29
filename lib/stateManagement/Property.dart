
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../utils.dart';
import 'miscValues.dart';
import 'undoable.dart';

enum PropType {
  number, hexInt, vector, string, bool
}

mixin Prop<T> implements Listenable, Undoable {
  abstract final PropType type;

  void updateWith(String str);

  static Prop fromString(String str, { bool isInteger = false, String? tagName }) {
    if (tagName == "name")
      return StringProp(str, true);
    else if (isHexInt(str))
      return HexProp(int.parse(str));
    else if (isDouble(str))
      return NumberProp(double.parse(str), isInteger);
    else if (isVector(str))
      return VectorProp(str.split(" ").map((val) => double.parse(val)).toList());
    else
      return StringProp(str, true);
  }
}

abstract class ValueProp<T> extends ValueNotifier<T> with Prop<T> {
  bool changesUndoable = true;

  ValueProp(super.value);

  @override
  void restoreWith(Undoable snapshot) {
    value = (snapshot as ValueProp).value;
  }

  @override
  set value(T value) {
    if (value == this.value) return;
    super.value = value;
    if (changesUndoable)
      undoHistoryManager.onUndoableEvent();
  }

  @override
  String toString() => value.toString();
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

class NumberProp extends ValueProp<num> {
  final bool isInteger;

  @override
  final PropType type = PropType.number;

  NumberProp(super.value, this.isInteger);

  @override
  String toString() => doubleToStr(value);
  
  @override
  void updateWith(String str) {
    value = double.parse(str);
  }

  @override
  Undoable takeSnapshot() {
    return NumberProp(value, isInteger);
  }
}

class VectorProp extends ChangeNotifier with Prop<List<num>>, IterableMixin<NumberProp> {
  @override
  final PropType type = PropType.vector;
  late final List<NumberProp> _values;

  VectorProp(List<num> values)
    : _values = List.from(values.map((v) => NumberProp(v, false)), growable: false)
  {
    for (var prop in _values)
      prop.addListener(notifyListeners);
  }
  
  @override
  void dispose() {
    for (var prop in _values)
      prop.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  Iterator<NumberProp> get iterator => _values.iterator;

  @override
  int get length => _values.length;

  NumberProp operator [](int index) => _values[index];

  void operator []=(int index, num value) {
    if (value == _values[index].value) return;
    _values[index].value = value;
    undoHistoryManager.onUndoableEvent();
  }

  @override
  String toString() => _values.map((p) => doubleToStr(p.value)).join(" ");
  
  @override
  void updateWith(String str) {
    var newValues = str.split(" ").map((val) => double.parse(val)).toList();
    for (int i = 0; i < length; i++) {
      _values[i].value = newValues[i];
    }
    undoHistoryManager.onUndoableEvent();
  }

  @override
  Undoable takeSnapshot() {
    return VectorProp(_values.map((p) => p.value).toList());
  }

  @override
  void restoreWith(Undoable snapshot) {
    var prop = snapshot as VectorProp;
    if (listEquals(_values, prop._values)) return;
    for (int i = 0; i < length; i++)
      _values[i].value = prop._values[i].value;
  }
}

class StringProp extends ValueProp<String> {
  @override
  final PropType type = PropType.string;
  
  String Function(String)? transform;

  StringProp(super.value, [ bool isTranslatable = false ]) {
    if (isTranslatable) {
      transform = tryToTranslate;
      shouldAutoTranslate.addListener(notifyListeners);
    }
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
  String toString({ bool shouldTransform = true }) 
    => shouldTransform && transform != null ? transform!(value) : value;

  @override
  Undoable takeSnapshot() {
    return StringProp(value, transform != null);
  }
}

class BoolProp extends ValueProp<bool> {
  @override
  final PropType type = PropType.bool;

  BoolProp(super.value);

  @override
  String toString() => value ? "true" : "false";
  
  @override
  void updateWith(String str) {
    value = str == "true";
  }

  @override
  Undoable takeSnapshot() {
    return BoolProp(value);
  }
}
  