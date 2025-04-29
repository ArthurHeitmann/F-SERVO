import 'dart:typed_data';

import '../../fileSystem/FileSystem.dart';
import 'ByteDataWrapper.dart';


class _BufferedReader {
  final RandomAccessFile _file;
  final Uint8List _buffer = Uint8List(_bufferCapacity);
  static const int _bufferCapacity = 1024 * 1024;
  int _position = 0;
  int _bufferStart = 0;
  int _bufferSize = -1;

  _BufferedReader(this._file);
  
  Future<void> close() {
    return _file.close();
  }
  
  void setPosition(int pos) {
    _position = pos;
  }
  
  Future<Uint8List> read(int length) async {
    if (length > _bufferCapacity) {
      if (_position != _bufferStart)
        await _file.setPosition(_position);
      return _file.read(length);
    }
    if (_position < _bufferStart || _position + length > _bufferStart + _bufferCapacity || _bufferSize == -1) {
      await _fillBuffer();
    }
    var bufferOffset = _position - _bufferStart;
    if (bufferOffset >= _bufferSize) {
      throw Exception("Reached end of file! Tried to read $length bytes at $_position when file only has ${_bufferStart + _bufferSize} bytes");
    }
    return _buffer.sublist(bufferOffset, bufferOffset + length);
  }

  Future<void> _fillBuffer() async {
    await _file.setPosition(_position);
    _bufferStart = _position;
    _bufferSize = await _file.readInto(_buffer);
  }
}

class ByteDataWrapperRA {
  final _BufferedReader _file;
  Endian endian;
  final int length;
  int _position = 0;
  
  ByteDataWrapperRA(RandomAccessFile file, this.length, { this.endian = Endian.little })
    : _file = _BufferedReader(file);


  static Future<ByteDataWrapperRA> fromFile(String path) async {
    var file = await FS.i.open(path);
    var length = await file.length();
    return ByteDataWrapperRA(file, length);
  }

  Future<void> close() async {
    await _file.close();
  }

  int get position => _position;

  void setPosition(int value) {
    if (value > length)
      throw RangeError.range(value, 0, length, "File size");
    
    _file.setPosition(value);
    _position = value;
  }

  Future<ByteData> _read(int length) async {
    var bytes = await _file.read(length);
    setPosition(_position + length);
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
