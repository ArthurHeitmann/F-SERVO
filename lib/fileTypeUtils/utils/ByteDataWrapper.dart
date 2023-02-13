
import 'dart:convert';
import 'dart:io';
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

  ByteDataWrapper.allocate(int size, { this.endian = Endian.little }) : 
    buffer = ByteData(size).buffer,
    _parentOffset = 0,
    length = size,
    _position = 0 {
    _data = buffer.asByteData(0, buffer.lengthInBytes);
  }

  static Future<ByteDataWrapper> fromFile(String path) async {
    var buffer = await File(path).readAsBytes();
    return ByteDataWrapper(buffer.buffer);
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
    return list;
  }

  List<double> readFloat64List(int length) {
    var list = List<double>.generate(length, (_) => readFloat64());
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

  List<int> asUint8List(int length) {
    var list = Uint8List.view(buffer, _position, length);
    _position += length;
    return list;
  }

  List<int> asUint16List(int length) {
    var list = Uint16List.view(buffer, _position, length);
    _position += length * 2;
    return list;
  }

  List<int> asUint32List(int length) {
    var list = Uint32List.view(buffer, _position, length);
    _position += length * 4;
    return list;
  }

  List<int> asUint64List(int length) {
    var list = Uint64List.view(buffer, _position, length);
    _position += length * 8;
    return list;
  }

  List<int> asInt8List(int length) {
    var list = Int8List.view(buffer, _position, length);
    _position += length;
    return list;
  }

  List<int> asInt16List(int length) {
    var list = Int16List.view(buffer, _position, length);
    _position += length * 2;
    return list;
  }

  List<int> asInt32List(int length) {
    var list = Int32List.view(buffer, _position, length);
    _position += length * 4;
    return list;
  }

  String readString(int length, {StringEncoding encoding = StringEncoding.utf8}) {
    List<int> bytes;
    if (encoding != StringEncoding.utf16)
      bytes = readUint8List(length);
    else
      bytes = readUint16List(length ~/ 2);
    return decodeString(bytes, encoding);
  }

  String _readStringZeroTerminatedUtf16() {
    var bytes = <int>[];
    while (true) {
      var byte = _data.getUint16(_position, endian);
      _position += 2;
      if (byte == 0) break;
      bytes.add(byte);
    }
    return decodeString(bytes, StringEncoding.utf16);
  }

  String readStringZeroTerminated({StringEncoding encoding = StringEncoding.utf8}) {
    if (encoding == StringEncoding.utf16)
      return _readStringZeroTerminatedUtf16();
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
    var codes = encodeString(value, encoding);
    if (encoding == StringEncoding.utf16) {
      for (var code in codes) {
        _data.setUint16(_position, code, endian);
        _position += 2;
      }
    } else {
      for (var code in codes) {
        _data.setUint8(_position, code);
        _position += 1;
      }
    }
  }

  static const _zeroStr = "\x00";
  void writeString0P(String value, [StringEncoding encoding = StringEncoding.utf8]) {
    writeString(value + _zeroStr, encoding);
  }

  void writeBytes(List<int> value) {
    for (var byte in value) {
      _data.setUint8(_position, byte);
      _position += 1;
    }
  }
}

String decodeString(List<int> codes, StringEncoding encoding) {
  switch (encoding) {
    case StringEncoding.utf8:
      return utf8.decode(codes, allowMalformed: true);
    case StringEncoding.utf16:
      return String.fromCharCodes(codes);
    case StringEncoding.shiftJis:
      return ShiftJIS().decode(codes);
  }
}

List<int> encodeString(String str, StringEncoding encoding) {
  switch (encoding) {
    case StringEncoding.utf8:
      return utf8.encode(str);
    case StringEncoding.utf16:
      return str.codeUnits;
    case StringEncoding.shiftJis:
      return ShiftJIS().encode(str);
  }
}
