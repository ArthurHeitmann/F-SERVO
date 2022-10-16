
import 'dart:convert';
import 'dart:typed_data';

import 'package:euc/jis.dart';

enum StringEncoding {
  utf8,
  utf16,
  shiftJis,
}

class ByteDataWrapper {
  final ByteBuffer buffer;
  late final ByteData _data;
  Endian endian;
  final int _parentOffset;
  final int length;
  int _position = 0;
  
  ByteDataWrapper(this.buffer, {
    this.endian = Endian.little,
    int parentOffset = 0,
    int? length,
  }) :
    _parentOffset = parentOffset,
    length = length ?? buffer.lengthInBytes - parentOffset {
    _data = buffer.asByteData(0, buffer.lengthInBytes);
    _position = _parentOffset;
  }

  int get position => _position;

  set position(int value) {
    if (value < 0 || value > length)
      throw RangeError.range(value, 0, _data.lengthInBytes, "View size");
    if (value > buffer.lengthInBytes)
      throw RangeError.range(value, 0, buffer.lengthInBytes, "Buffer size");
    
    _position = value + _parentOffset;
  }

  double readFloat32() {
    var value = _data.getFloat32(_position, endian);
    _position += 4;
    return value;
  }

  double readFloat64() {
    var value = _data.getFloat64(_position, endian);
    _position += 8;
    return value;
  }

  int readInt8() {
    var value = _data.getInt8(_position);
    _position += 1;
    return value;
  }

  int readInt16() {
    var value = _data.getInt16(_position, endian);
    _position += 2;
    return value;
  }

  int readInt32() {
    var value = _data.getInt32(_position, endian);
    _position += 4;
    return value;
  }

  int readInt64() {
    var value = _data.getInt64(_position, endian);
    _position += 8;
    return value;
  }

  int readUint8() {
    var value = _data.getUint8(_position);
    _position += 1;
    return value;
  }

  int readUint16() {
    var value = _data.getUint16(_position, endian);
    _position += 2;
    return value;
  }

  int readUint32() {
    var value = _data.getUint32(_position, endian);
    _position += 4;
    return value;
  }

  int readUint64() {
    var value = _data.getUint64(_position, endian);
    _position += 8;
    return value;
  }

  List<double> readFloat32List(int length) {
    var list = List<double>.generate(length, (_) => readFloat32());
    _position += length * 4;
    return list;
  }

  List<double> readFloat64List(int length) {
    var list = List<double>.generate(length, (_) => readFloat64());
    _position += length * 8;
    return list;
  }

  List<int> readInt8List(int length) {
    return List<int>.generate(length, (_) => readInt8());
  }

  List<int> readInt16List(int length) {
    return List<int>.generate(length, (_) => readInt16());
  }

  List<int> readInt32List(int length) {
    return List<int>.generate(length, (_) => readInt32());
  }

  List<int> readInt64List(int length) {
    return List<int>.generate(length, (_) => readInt64());
  }

  List<int> readUint8List(int length) {
    return List<int>.generate(length, (_) => readUint8());
  }

  List<int> readUint16List(int length) {
    return List<int>.generate(length, (_) => readUint16());
  }

  List<int> readUint32List(int length) {
    return List<int>.generate(length, (_) => readUint32());
  }

  List<int> readUint64List(int length) {
    return List<int>.generate(length, (_) => readUint64());
  }

  String readString(int length, {StringEncoding encoding = StringEncoding.utf8}) {
    var bytes = readUint8List(length);
    return decodeString(bytes, encoding);
  }

  String readStringZeroTerminated({StringEncoding encoding = StringEncoding.utf8}) {
    var bytes = <int>[];
    while (true) {
      var byte = _data.getUint8(_position);
      _position += 1;
      if (byte == 0) break;
      bytes.add(byte);
    }
    return decodeString(bytes, encoding);
  }

  ByteDataWrapper makeSubView(int length) {
    return ByteDataWrapper(buffer, endian: endian, parentOffset: _position, length: length);
  }

  void writeFloat32(double value) {
    _data.setFloat32(_position, value, endian);
    _position += 4;
  }

  void writeFloat64(double value) {
    _data.setFloat64(_position, value, endian);
    _position += 8;
  }

  void writeInt8(int value) {
    _data.setInt8(_position, value);
    _position += 1;
  }

  void writeInt16(int value) {
    _data.setInt16(_position, value, endian);
    _position += 2;
  }

  void writeInt32(int value) {
    _data.setInt32(_position, value, endian);
    _position += 4;
  }

  void writeInt64(int value) {
    _data.setInt64(_position, value, endian);
    _position += 8;
  }

  void writeUint8(int value) {
    _data.setUint8(_position, value);
    _position += 1;
  }

  void writeUint16(int value) {
    _data.setUint16(_position, value, endian);
    _position += 2;
  }

  void writeUint32(int value) {
    _data.setUint32(_position, value, endian);
    _position += 4;
  }

  void writeUint64(int value) {
    _data.setUint64(_position, value, endian);
    _position += 8;
  }

  void writeString(String value, [StringEncoding encoding = StringEncoding.utf8]) {
    var bytes = encodeString(value, encoding);
    for (var byte in bytes) {
      _data.setUint8(_position, byte);
      _position += 1;
    }
  }

  void writeString0P(String value, [StringEncoding encoding = StringEncoding.utf8]) {
    writeString(value, encoding);
    _data.setUint8(_position, 0);
    _position += 1;
  }

  void writeBytes(List<int> value) {
    for (var byte in value) {
      _data.setUint8(_position, byte);
      _position += 1;
    }
  }
}

String decodeString(List<int> bytes, StringEncoding encoding) {
  switch (encoding) {
    case StringEncoding.utf8:
      return String.fromCharCodes(bytes);
    case StringEncoding.utf16:
      return String.fromCharCodes(bytes); // TODO check if actually works
    case StringEncoding.shiftJis:
      return ShiftJIS().decode(bytes);
  }
}

List<int> encodeString(String value, StringEncoding encoding) {
  switch (encoding) {
    case StringEncoding.utf8:
      return utf8.encode(value);
    case StringEncoding.utf16:
      return value.codeUnits; // TODO check if actually works
    case StringEncoding.shiftJis:
      return ShiftJIS().encode(value);
  }
}
