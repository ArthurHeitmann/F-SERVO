
import 'dart:typed_data';

import 'package:charset/charset.dart';

enum StringEncoding {
  utf8,
  utf16,
  shiftJis,
}

class ByteDataWrapper {
  final ByteData _data;
  Endian endian;
  int _position = 0;
  static final ShiftJISDecoder _shiftJisDecoder = ShiftJISDecoder();
  static final ShiftJISEncoder _shiftJisEncoder = ShiftJISEncoder();
  
  ByteBuffer get buffer => _data.buffer;

  ByteDataWrapper(this._data, {this.endian = Endian.little});

  int get position => _position;

  
  set position(int value) {
    if (value < 0 || value > _data.lengthInBytes)
      throw RangeError.range(value, 0, _data.lengthInBytes);
    _position = value;
  }

  int get length => _data.lengthInBytes;

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
    var list = _data.buffer.asFloat32List(_position, length);
    _position += length * 4;
    return list;
  }

  List<double> readFloat64List(int length) {
    var list = _data.buffer.asFloat64List(_position, length);
    _position += length * 8;
    return list;
  }

  List<int> readInt8List(int length) {
    var list = _data.buffer.asInt8List(_position, length);
    _position += length;
    return list;
  }

  List<int> readInt16List(int length) {
    var list = _data.buffer.asInt16List(_position, length);
    _position += length * 2;
    return list;
  }

  List<int> readInt32List(int length) {
    var list = _data.buffer.asInt32List(_position, length);
    _position += length * 4;
    return list;
  }

  List<int> readInt64List(int length) {
    var list = _data.buffer.asInt64List(_position, length);
    _position += length * 8;
    return list;
  }

  List<int> readUint8List(int length) {
    var list = _data.buffer.asUint8List(_position, length);
    _position += length;
    return list;
  }

  List<int> readUint16List(int length) {
    var list = _data.buffer.asUint16List(_position, length);
    _position += length * 2;
    return list;
  }

  List<int> readUint32List(int length) {
    var list = _data.buffer.asUint32List(_position, length);
    _position += length * 4;
    return list;
  }

  List<int> readUint64List(int length) {
    var list = _data.buffer.asUint64List(_position, length);
    _position += length * 8;
    return list;
  }

  String readString(int length, {StringEncoding encoding = StringEncoding.utf8}) {
    var bytes = _data.buffer.asUint8List(_position, length);
    _position += length;
    switch (encoding) {
      case StringEncoding.utf8:
        return String.fromCharCodes(bytes);
      case StringEncoding.utf16:
        return String.fromCharCodes(bytes.buffer.asUint16List());
      case StringEncoding.shiftJis:
        return _shiftJisDecoder.convert(bytes);
    }
  }

  List<int> readBytes(int length) {
    var bytes = _data.buffer.asUint8List(_position, length);
    _position += length;
    return bytes;
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

  void writeString(String value) {
    var bytes = value.codeUnits;
    _data.buffer.asUint8List(_position, bytes.length).setAll(0, bytes);
    _position += bytes.length;
  }

  void writeBytes(List<int> value) {
    _data.buffer.asUint8List(_position, value.length).setAll(0, value);
    _position += value.length;
  }
}