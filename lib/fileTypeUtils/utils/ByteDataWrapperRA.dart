import 'dart:io';
import 'dart:typed_data';

import 'ByteDataWrapper.dart';


class ByteDataWrapperRA {
  final RandomAccessFile file;
  Endian endian;
  final int length;
  int _position = 0;
  
  ByteDataWrapperRA(this.file, this.length, { this.endian = Endian.little });


  static Future<ByteDataWrapperRA> fromFile(String path) async {
    var file = await File(path).open();
    var length = await file.length();
    return ByteDataWrapperRA(file, length);
  }

  Future<void> close() async {
    await file.close();
  }

  int get position => _position;

  Future<void> setPosition(int value) async {
    if (value > length)
      throw RangeError.range(value, 0, length, "File size");
    
    await file.setPosition(value);
    _position = value;
  }

  Future<ByteData> _read(int length) async {
    var bytes = await file.read(length);
    await setPosition(_position + length);
    return ByteData.view(bytes.buffer);
  }

  Future<double> readFloat32() async {
    var bytes = await _read(4);
    return bytes.getFloat32(0, endian);
  }

  Future<double> readFloat64() async {
    var bytes = await _read(8);
    return bytes.getFloat64(0, endian);
  }

  Future<int> readInt8() async {
    var bytes = await _read(1);
    return bytes.getInt8(0);
  }

  Future<int> readInt16() async {
    var bytes = await _read(2);
    return bytes.getInt16(0, endian);
  }

  Future<int> readInt32() async {
    var bytes = await _read(4);
    return bytes.getInt32(0, endian);
  }

  Future<int> readInt64() async {
    var bytes = await _read(8);
    return bytes.getInt64(0, endian);
  }

  Future<int> readUint8() async {
    var bytes = await _read(1);
    return bytes.getUint8(0);
  }

  Future<int> readUint16() async {
    var bytes = await _read(2);
    return bytes.getUint16(0, endian);
  }

  Future<int> readUint32() async {
    var bytes = await _read(4);
    return bytes.getUint32(0, endian);
  }

  Future<int> readUint64() async {
    var bytes = await _read(8);
    return bytes.getUint64(0, endian);
  }

  Future<Int8List> readInt8List(int length) async {
    var bytes = await _read(length);
    return bytes.buffer.asInt8List();
  }

  Future<Int16List> readInt16List(int length) async {
    var bytes = await _read(length * 2);
    return bytes.buffer.asInt16List();
  }

  Future<Int32List> readInt32List(int length) async {
    var bytes = await _read(length * 4);
    return bytes.buffer.asInt32List();
  }

  Future<Int64List> readInt64List(int length) async {
    var bytes = await _read(length * 8);
    return bytes.buffer.asInt64List();
  }

  Future<Uint8List> readUint8List(int length) async {
    var bytes = await _read(length);
    return bytes.buffer.asUint8List();
  }

  Future<Uint16List> readUint16List(int length) async {
    var bytes = await _read(length * 2);
    return bytes.buffer.asUint16List();
  }

  Future<Uint32List> readUint32List(int length) async {
    var bytes = await _read(length * 4);
    return bytes.buffer.asUint32List();
  }

  Future<Uint64List> readUint64List(int length) async {
    var bytes = await _read(length * 8);
    return bytes.buffer.asUint64List();
  }

  Future<String> readString(int length, {StringEncoding encoding = StringEncoding.utf8}) async {
    List<int> bytes;
    if (encoding != StringEncoding.utf16)
      bytes = await readUint8List(length);
    else
      bytes = await readUint16List(length ~/ 2);
    return decodeString(bytes, encoding);
  }

  Future<String> _readStringZeroTerminatedUtf16() async {
    var bytes = <int>[];
    while (true) {
      var byte = await readUint16();
      if (byte == 0) break;
      bytes.add(byte);
    }
    return decodeString(bytes, StringEncoding.utf16);
  }

  Future<String> readStringZeroTerminated({StringEncoding encoding = StringEncoding.utf8}) async {
    if (encoding == StringEncoding.utf16)
      return _readStringZeroTerminatedUtf16();
    var bytes = <int>[];
    while (true) {
      var byte = await readUint8();
      if (byte == 0) break;
      bytes.add(byte);
    }
    return decodeString(bytes, encoding);
  }
}
