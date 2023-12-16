
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../fileTypeUtils/yax/hashToStringMap.dart';
import '../utils/Disposable.dart';
import '../utils/utils.dart';
import 'hasUuid.dart';
import 'miscValues.dart';
import 'openFiles/openFilesManager.dart';
import 'undoable.dart';

enum PropType {
  number, hexInt, vector, string, bool, float
}

mixin Prop<T> implements Listenable, Undoable, Disposable {
  abstract final PropType type;
  abstract final OpenFileId? fileId;

  void updateWith(String str);

  static Prop fromString(String str, { required OpenFileId? fileId, bool isInteger = false, String? tagName }) {
    if (tagName == "name")
      return StringProp(str, isTranslatable: true, fileId: fileId);
    else if (isHexInt(str))
      return HexProp(int.parse(str), fileId: fileId);
    else if (isDouble(str))
      return NumberProp(double.parse(str), isInteger, fileId: fileId);
    else if (isVector(str))
      return VectorProp(str.split(" ").map((val) => double.parse(val)).toList(), fileId: fileId);
    else
      return StringProp(str, isTranslatable: true, fileId: fileId);
  }

  @override
  void dispose();
}

abstract class ValueProp<T> extends ValueNotifier<T> with Prop<T>, HasUuid {
  @override
  final OpenFileId? fileId;
  bool changesUndoable = true;

  ValueProp(super.value, { required this.fileId });

  @override
  void restoreWith(Undoable snapshot) {
    value = (snapshot as ValueProp).value;
  }

  @override
  set value(T value) {
    if (value == this.value) return;
    super.value = value;
    if (changesUndoable && fileId != null)
      areasManager.onFileIdUndoEvent(fileId!);
  }

  @override
  String toString() => value.toString();
}

class HexProp extends ValueProp<int> {
  @override
  final PropType type = PropType.hexInt;

  String? _strVal;

  HexProp(super.value, { required super.fileId }) {
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
    var prop = HexProp(value, fileId: fileId);
    prop.overrideUuid(uuid);
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

  NumberProp(super.value, this.isInteger, { required super.fileId });

  @override
  String toString() => doubleToStr(value);
  
  @override
  void updateWith(String str) {
    if (isInteger)
      value = int.parse(str);
    else
      value = double.parse(str);
  }

  @override
  Undoable takeSnapshot() {
    var prop = NumberProp(value, isInteger, fileId: fileId);
    prop.overrideUuid(uuid);
    return prop;
  }
}

class FloatProp extends ValueProp<double> {
  @override
  final PropType type = PropType.float;

  FloatProp(super.value, { required super.fileId });

  @override
  String toString() => doubleToStr(value);
  
  @override
  void updateWith(String str) {
    value = double.parse(str);
  }

  @override
  Undoable takeSnapshot() {
    var prop = FloatProp(value, fileId: fileId);
    prop.overrideUuid(uuid);
    return prop;
  }
}

class VectorProp extends ChangeNotifier with Prop<List<num>>, IterableMixin<NumberProp>, HasUuid {
  @override
  final OpenFileId? fileId;
  @override
  final PropType type = PropType.vector;
  late final List<NumberProp> _values;

  VectorProp(List<num> values, { required this.fileId })
    : _values = List.from(values.map((v) => NumberProp(v, false, fileId: fileId)), growable: false)
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
    if (fileId != null)
      areasManager.onFileIdUndoEvent(fileId!);
  }

  @override
  String toString() => _values.map((p) => doubleToStr(p.value)).join(" ");
  
  @override
  void updateWith(String str) {
    var newValues = str.split(" ").map((val) => double.parse(val)).toList();
    for (int i = 0; i < length; i++) {
      _values[i].value = newValues[i];
    }
    if (fileId != null)
      areasManager.onFileIdUndoEvent(fileId!);
  }

  @override
  Undoable takeSnapshot() {
    var prop = VectorProp(_values.map((p) => p.value).toList(), fileId: fileId);
    prop.overrideUuid(uuid);
    return prop;
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

  StringProp(super.value, { required super.fileId, bool isTranslatable = false }) {
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
    var prop = StringProp(value, isTranslatable: transform != null, fileId: fileId);
    prop.overrideUuid(uuid);
    return prop;
  }
}

class BoolProp extends ValueProp<bool> {
  @override
  final PropType type = PropType.bool;

  BoolProp(super.value, { required super.fileId });

  @override
  String toString() => value ? "true" : "false";
  
  @override
  void updateWith(String str) {
    value = str == "true";
  }

  @override
  Undoable takeSnapshot() {
    var prop = BoolProp(value, fileId: fileId);
    prop.overrideUuid(uuid);
    return prop;
  }
}

class AudioSampleNumberProp extends ValueProp<int> {
  final int samplesPerSecond;
  
  @override
  final PropType type = PropType.number;

  AudioSampleNumberProp(super.value, this.samplesPerSecond, { required super.fileId });

  @override
  String toString() {
    double seconds = value / samplesPerSecond;
    return formatDuration(Duration(milliseconds: (seconds * 1000).round()), true);
  }
  
  @override
  void updateWith(String str) {
    var matches = RegExp(r"(\d+):(\d+)\.(\d+)").firstMatch(str);
    if (matches == null)
      throw Exception("Invalid time format: $str");
    int min = int.parse(matches.group(1)!);
    int sec = int.parse(matches.group(2)!);
    int ms = int.parse(matches.group(3)!);
    if (min < 0 || sec < 0 || sec >= 60 || ms < 0 || ms >= 1000)
      throw Exception("Invalid time format: $str");
    value = ((min * 60 + sec + ms / 1000)  * samplesPerSecond).toInt();
  }

  @override
  Undoable takeSnapshot() {
    var prop = AudioSampleNumberProp(value, samplesPerSecond, fileId: fileId);
    prop.overrideUuid(uuid);
    return prop;
  }
}
