
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../utils/utils.dart';
import 'VirtualEntities.dart';
import 'VirtualFileSystem.dart';
import 'VirtualRandomAccessFile.dart';

export 'dart:io' show FileMode, FileSystemEntityType, RandomAccessFile, FileSystemException, Platform, IOSink;

enum _Platform {
  desktop,
  mobile,
  web,
}

class FS {
  static final FS i = FS._();

  late final _Platform _platform;
  final _virtualFs = VirtualFileSystem();

  FS._() {
    if (isMobile)
      _platform = _Platform.mobile;
    else if (isWeb)
      _platform = _Platform.web;
    else if (isDesktop)
      _platform = _Platform.desktop;
    else
      throw Exception("Unsupported platform");
  }
  
  bool get useVirtualFs => _platform != _Platform.desktop;

  VirtualEntity get virtualRoot => _virtualFs.root;

  Future<Uint8List> read(String path) async {
    if (useVirtualFs) {
      return _virtualFs.read(path);
    }
    else {
      return await File(path).readAsBytes();
    }
  }

  Future<String> readAsString(String path, {Encoding encoding = utf8}) async {
    if (useVirtualFs) {
      return utf8.decode(_virtualFs.read(path));
    }
    else {
      return await File(path).readAsString(encoding: encoding);
    }
  }
  
  Future<List<String>> readAsLines(String path) async {
    if (useVirtualFs) {
      return utf8.decode(_virtualFs.read(path)).split("\n").map((e) => e.endsWith("\r") ? e.substring(0, e.length - 1) : e).toList();
    }
    else {
      return await File(path).readAsLines();
    }
  }

  Future<RandomAccessFile> open(String path, {FileMode mode = FileMode.read}) async {
    if (useVirtualFs) {
      return VirtualRandomAccessFile(
        file: _virtualFs.getFile(path),
        allowRead: mode == FileMode.read || mode == FileMode.write,
        allowWrite: mode == FileMode.write || mode == FileMode.append || mode == FileMode.writeOnly || mode == FileMode.writeOnlyAppend,
        truncate: mode == FileMode.write || mode == FileMode.writeOnly,
        allowPositionChange: mode != FileMode.writeOnlyAppend,
      );
    }
    else {
      return await File(path).open(mode: mode);
    }
  }

  Stream<List<int>> openRead(String path) {
    if (useVirtualFs) {
      var bytes = _virtualFs.read(path);
      return Stream.fromIterable([bytes]);
    }
    else {
      return File(path).openRead();
    }
  }

  IOSink openWrite(String path, {FileMode mode = FileMode.write}) {
    if (useVirtualFs) {
      return VirtualIOSink(
        file: _virtualFs.getFile(path),
        truncate: mode == FileMode.write || mode == FileMode.writeOnly,
      );
    }
    else {
      return File(path).openWrite(mode: mode);
    }
  }

  Future<void> write(String path, List<int> data) async {
    if (useVirtualFs) {
      _virtualFs.write(path, data);
    }
    else {
      await File(path).writeAsBytes(data);
    }
  }

  Future<void> writeAsString(String path, String data, {Encoding encoding = utf8}) async {
    if (useVirtualFs) {
      _virtualFs.write(path, encoding.encode(data));
    }
    else {
      await File(path).writeAsString(data, encoding: encoding);
    }
  }

  Future<void> delete(String path) async {
    if (useVirtualFs) {
      _virtualFs.deleteFile(path);
    }
    else {
      await File(path).delete();
    }
  }

  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    if (useVirtualFs) {
      _virtualFs.deleteFolder(path, recursive: recursive);
    }
    else {
      await Directory(path).delete(recursive: recursive);
    }
  }

  Future<void> createFile(String path) async {
    if (useVirtualFs) {
      _virtualFs.createFile(path);
    }
    else {
      await File(path).create(recursive: true);
    }
  }

  Future<void> createDirectory(String path) async {
    if (useVirtualFs) {
      _virtualFs.createFolder(path);
    }
    else {
      await Directory(path).create(recursive: true);
    }
  }

  Future<String> createTempDirectory(String prefix) async {
    if (useVirtualFs) {
      return _virtualFs.createTempFolder(prefix);
    }
    else {
      return (await Directory.systemTemp.createTemp(prefix)).path;
    }
  }

  Future<void> renameFile(String oldPath, String newPath) async {
    if (useVirtualFs) {
      _virtualFs.moveFile(oldPath, newPath);
    }
    else {
      await File(oldPath).rename(newPath);
    }
  }

  // Future<void> renameDirectory(String oldPath, String newPath) async {
  //   if (_useVirtualFs) {
  //     throw Exception("Unsupported platform for renaming directories");
  //   }
  //   else {
  //     await Directory(oldPath).rename(newPath);
  //   }
  // }

  Future<void> copyFile(String oldPath, String newPath) async {
    if (useVirtualFs) {
      _virtualFs.copyFile(oldPath, newPath);
    }
    else {
      await File(oldPath).copy(newPath);
    }
  }

  Future<bool> existsFile(String path) async {
    if (useVirtualFs) {
      return _virtualFs.existsFile(path);
    }
    else {
      return await File(path).exists();
    }
  }

  bool existsFileSync(String path) {
    if (useVirtualFs) {
      return _virtualFs.existsFile(path);
    }
    else {
      return File(path).existsSync();
    }
  }

  Future<bool> existsDirectory(String path) async {
    if (useVirtualFs) {
      return _virtualFs.existsFolder(path);
    }
    else {
      return await Directory(path).exists();
    }
  }

  bool existsDirectorySync(String path) {
    if (useVirtualFs) {
      return _virtualFs.existsFolder(path);
    }
    else {
      return Directory(path).existsSync();
    }
  }

  Future<bool> exists(String path) async {
    if (useVirtualFs) {
      return _virtualFs.exists(path);
    }
    else {
      return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
    }
  }

  bool existsSync(String path) {
    if (useVirtualFs) {
      return _virtualFs.exists(path);
    }
    else {
      return FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
    }
  }

  Stream<FileSystemEntity> list(String path, {bool recursive = false}) {
    if (useVirtualFs) {
      return Stream.fromIterable(_virtualFs.list(path)).map((e) {
        if (e is VirtualFile) {
          return File(e.path);
        } else if (e is VirtualFolder) {
          return Directory(e.path);
        } else {
          throw Exception("Unknown entity type: ${e.runtimeType}");
        }
      });
    }
    else {
      return Directory(path).list(recursive: recursive);
    }
  }

  Stream<String> listFiles(String path, {bool recursive = false}) {
    if (useVirtualFs) {
      return Stream.fromIterable(_virtualFs.list(path)).where((e) => e is VirtualFile).map((e) => e.path);
    }
    else {
      return Directory(path).list(recursive: recursive).where((e) => e is File).map((e) => e.path);
    }
  }
  
  Stream<String> listDirectories(String path, {bool recursive = false}) {
    if (useVirtualFs) {
      return Stream.fromIterable(_virtualFs.list(path)).where((e) => e is VirtualFolder).map((e) => e.path);
    }
    else {
      return Directory(path).list(recursive: recursive).where((e) => e is Directory).map((e) => e.path);
    }
  }

  Future<int> getSize(String path) async {
    if (useVirtualFs) {
      return _virtualFs.getFileSize(path);
    }
    else {
      return await File(path).length();
    }
  }

  Future<List<String>> selectFiles({
    String? dialogTitle,
    String? initialDirectory,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    var files = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
    );
    if (files == null)
      return [];
    List<String> paths;
    if (_platform == _Platform.web) {
      paths = files.files.map((e) => "\$opened/${e.name}").toList();
    } else {
      paths = files.paths.whereType<String>().toList();
    }
    for (var (i, file) in files.files.indexed) {
      if (file.bytes != null)
        registerFile(paths[i], file.bytes!);
    }
    return paths;
  }

  Future<String?> selectDirectory({
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    if (_platform == _Platform.web)
      throw Exception("Directory selection is not supported on web");
    var directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
    return directory;
  }

  Future<String?> selectSaveFile({
    String? initialDirectory,
    String? fileName,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    if (_platform == _Platform.web)
      throw Exception("File selection is not supported on web");
    var file = await FilePicker.platform.saveFile(
      initialDirectory: initialDirectory,
      fileName: fileName,
      dialogTitle: dialogTitle,
      allowedExtensions: allowedExtensions,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
    );
    return file;
  }

  Future<String?> saveFile({
    required String fileName,
    Uint8List? bytes,
    Future<Uint8List> Function()? getBytes,
    String? text,
    String? initialDirectory,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    if (bytes == null && text != null)
      bytes = utf8.encode(text);
    if (bytes == null && isWeb)
      bytes = await getBytes!();
    if (bytes == null && isWeb)
      throw Exception("No data to save");
    var file = await FilePicker.platform.saveFile(
      initialDirectory: initialDirectory,
      fileName: fileName,
      dialogTitle: dialogTitle,
      allowedExtensions: allowedExtensions,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      bytes: bytes != null ? Uint8List.fromList(bytes) : null,
    );
    if (bytes == null && getBytes != null)
      bytes = await getBytes();
    if (_platform == _Platform.desktop && file != null)
      await write(file, bytes!);
    return file;
  }

  void registerFile(String path, List<int> bytes) {
    if (!useVirtualFs)
      return;
    _virtualFs.write(path, bytes);
  }
}
