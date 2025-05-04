
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'VirtualEntities.dart';

class VirtualRandomAccessFile implements RandomAccessFile {
  late final VirtualFile _file;
  final bool _allowRead;
  final bool _allowWrite;
  final bool _allowPositionChange;
  late ByteData _buffer;
  late int _size;
  int _position = 0;
  int get _capacity => _buffer.lengthInBytes;

  VirtualRandomAccessFile({
    required VirtualFile file,
    required bool allowRead,
    required bool allowWrite,
    required bool truncate,
    required bool allowPositionChange,
  }) :
    _file = file,
    _allowWrite = allowWrite,
    _allowRead = allowRead,
    _allowPositionChange = allowPositionChange
  {
    if (!_allowRead && !_allowWrite)
      throw Exception("VirtualRandomAccessFile must allow read or write");
    if (truncate) {
      _buffer = ByteData(0);
      _size = 0;
    }
    else {
      _buffer = ByteData(max(_file.bytes.length, 1024));
      _size = _file.bytes.length;
      _buffer.buffer.asUint8List().setAll(0, _file.bytes);
      _position = _size;
    }
  }

  void _allocate(int newSize) {
    if (newSize > _buffer.lengthInBytes) {
      var newBuffer = ByteData(newSize);
      newBuffer.buffer.asUint8List().setAll(0, Uint8List.view(_buffer.buffer, 0, _size));
      _buffer = newBuffer;
    }
  }

  void _ensureCapacity(int neededCapacity) {
    if (neededCapacity > _capacity) {
      _allocate(max(_capacity * 2, neededCapacity));
    }
  }

  @override
  Future<void> close() async {
    closeSync();
  }

  @override
  void closeSync() {
    flushSync();
  }

  @override
  Future<RandomAccessFile> flush() async {
    flushSync();
    return this;
  }

  @override
  void flushSync() {
    if (!_allowWrite)
      return;
    var fileBytes = Uint8List(_size);
    fileBytes.setAll(0, Uint8List.view(_buffer.buffer, 0, _size));
    _file.bytes = fileBytes;
  }

  @override
  Future<int> length() async {
    return lengthSync();
  }

  @override
  int lengthSync() {
    return _size;
  }

  @override
  Future<RandomAccessFile> lock([FileLock mode = FileLock.exclusive, int start = 0, int end = -1]) async {
    lockSync(mode, start, end);
    return this;
  }

  @override
  void lockSync([FileLock mode = FileLock.exclusive, int start = 0, int end = -1]) {
  }

  @override
  String get path => _file.path;

  @override
  Future<int> position() async {
    return positionSync();
  }

  @override
  int positionSync() {
    return _position;
  }

  @override
  Future<Uint8List> read(int count) async {
    return readSync(count);
  }

  @override
  Future<int> readByte() async {
    return readByteSync();
  }

  @override
  int readByteSync() {
    if (_position >= _size)
      return -1;
    if (!_allowRead)
      throw Exception("VirtualRandomAccessFile is write-only");
    int byte = _buffer.getUint8(_position);
    _position++;
    return byte;
  }

  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) async {
    return readIntoSync(buffer, start, end);
  }

  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) {
    if (start < 0 || start >= buffer.length)
      throw RangeError.range(start, 0, buffer.length, "start");
    if (end != null && (end < 0 || end > buffer.length || end < start))
      throw RangeError.range(end, 0, buffer.length, "end");
    if (!_allowRead)
      throw Exception("VirtualRandomAccessFile is write-only");
    end ??= buffer.length;
    var readCount = min(end - start, _size - _position);
    _buffer.buffer.asUint8List().setAll(start, Uint8List.view(_buffer.buffer, _position, readCount));
    _position += readCount;
    return readCount;
  }

  @override
  Uint8List readSync(int count) {
    if (count < 0)
      throw RangeError.range(count, 0, null, "count");
    if (!_allowRead)
      throw Exception("VirtualRandomAccessFile is write-only");
    var start = _position;
    var end = min(_position + count, _size);
    _position = end;
    if (start >= end)
      return Uint8List(0);
    return Uint8List.sublistView(_buffer, start, end);
  }

  @override
  Future<RandomAccessFile> setPosition(int position) async {
    setPositionSync(position);
    return this;
  }

  @override
  void setPositionSync(int position) {
    if (position < 0)
      throw RangeError.range(position, 0, null, "position");
    if (!_allowPositionChange)
      throw Exception("VirtualRandomAccessFile is append-only");
    _position = position;
  }

  @override
  Future<RandomAccessFile> truncate(int length) async {
    truncateSync(length);
    return this;
  }

  @override
  void truncateSync(int length) {
    if (length < 0)
      throw RangeError.range(length, 0, null, "length");
    if (!_allowWrite)
      throw Exception("VirtualRandomAccessFile is read-only");
    if (length == _size)
      return;
    if (length > _size) {
      _allocate(length);
    }
    _size = length;
    _position = min(_position, _size);
  }

  @override
  Future<RandomAccessFile> unlock([int start = 0, int end = -1]) async {
    unlockSync(start, end);
    return this;
  }

  @override
  void unlockSync([int start = 0, int end = -1]) {
  }

  @override
  Future<RandomAccessFile> writeByte(int value) async {
    writeByteSync(value);
    return this;
  }

  @override
  int writeByteSync(int value) {
    if (!_allowWrite)
      throw Exception("VirtualRandomAccessFile is read-only");
    _ensureCapacity(_position + 1);
    _buffer.setUint8(_position, value);
    _position++;
    _size = max(_size, _position);
    return 1;
  }

  @override
  Future<RandomAccessFile> writeFrom(List<int> buffer, [int start = 0, int? end]) async {
    writeFromSync(buffer, start, end);
    return this;
  }

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) {
    if (start < 0 || start >= buffer.length)
      throw RangeError.range(start, 0, buffer.length, "start");
    if (end != null && (end < 0 || end > buffer.length || end < start))
      throw RangeError.range(end, 0, buffer.length, "end");
    if (!_allowWrite)
      throw Exception("VirtualRandomAccessFile is read-only");
    end ??= buffer.length;
    var writeCount = end - start;
    _ensureCapacity(_position + writeCount);
    _buffer.buffer.asUint8List().setAll(_position, buffer.sublist(start, end));
    _position += writeCount;
    _size = max(_size, _position);
  }

  @override
  Future<RandomAccessFile> writeString(String string, {Encoding encoding = utf8}) async {
    writeStringSync(string, encoding: encoding);
    return this;
  }

  @override
  void writeStringSync(String string, {Encoding encoding = utf8}) {
    if (!_allowWrite)
      throw Exception("VirtualRandomAccessFile is read-only");
    var bytes = encoding.encode(string);
    _ensureCapacity(_position + bytes.length);
    _buffer.buffer.asUint8List().setAll(_position, bytes);
    _position += bytes.length;
    _size = max(_size, _position);
  }
}

class VirtualIOSink implements IOSink {
  final VirtualRandomAccessFile _file;
  @override
  Encoding encoding;

  VirtualIOSink({
    required VirtualFile file,
    required bool truncate,
    this.encoding = utf8
  }) : _file = VirtualRandomAccessFile(
    file: file,
    allowRead: false,
    allowWrite: true,
    truncate: truncate,
    allowPositionChange: true,
  );

  
  @override
  void add(List<int> data) {
    _file.writeFromSync(data);
  }
  
  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    throw UnimplementedError("addError is not implemented");
  }
  
  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (var data in stream) {
      add(data);
    }
  }
  
  @override
  Future close() {
    return _file.close();
  }
  
  @override
  Future get done => throw UnimplementedError();
  
  @override
  Future flush() {
    return _file.flush();
  }
  
  @override
  void write(Object? object) {
    _file.writeStringSync(object.toString(), encoding: encoding);
  }
  
  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    for (var object in objects) {
      write(object);
      if (object != objects.last) {
        _file.writeStringSync(separator, encoding: encoding);
      }
    }
  }
  
  @override
  void writeCharCode(int charCode) {
    _file.writeByteSync(charCode);
  }
  
  @override
  void writeln([Object? object = ""]) {
    write(object);
    _file.writeStringSync("\n", encoding: encoding);
  }
}
