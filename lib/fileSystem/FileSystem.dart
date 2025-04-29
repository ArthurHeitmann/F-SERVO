
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../utils/utils.dart';

export 'dart:io' show FileMode, FileSystemEntityType, RandomAccessFile, FileSystemException, Platform, IOSink;

enum _Platform {
  desktop,
  mobile,
  web,
}

class FS {
  static final FS i = FS._();

  late final _Platform _platform;

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

  Future<Uint8List> read(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        return await File(path).readAsBytes();
      default:
        throw Exception("Unsupported platform for reading files");
    }
  }

  Future<String> readAsString(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        return await File(path).readAsString();
      default:
        throw Exception("Unsupported platform for reading files");
    }
  }
  
  Future<List<String>> readAsLines(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        return await File(path).readAsLines();
      default:
        throw Exception("Unsupported platform for reading files");
    }
  }

  Future<RandomAccessFile> open(String path, {FileMode mode = FileMode.read}) async {
    switch (_platform) {
      case _Platform.desktop:
        return await File(path).open(mode: mode);
      default:
        throw Exception("Unsupported platform for opening files");
    }
  }

  Stream<List<int>> openRead(String path) {
    switch (_platform) {
      case _Platform.desktop:
        return File(path).openRead();
      default:
        throw Exception("Unsupported platform for opening files");
    }
  }

  IOSink openWrite(String path, {FileMode mode = FileMode.write}) {
    switch (_platform) {
      case _Platform.desktop:
        return File(path).openWrite(mode: mode);
      default:
        throw Exception("Unsupported platform for opening files");
    }
  }

  Future<void> write(String path, List<int> data) async {
    switch (_platform) {
      case _Platform.desktop:
        await File(path).writeAsBytes(data);
        break;
      default:
        throw Exception("Unsupported platform for writing files");
    }
  }

  Future<void> writeAsString(String path, String data) async {
    switch (_platform) {
      case _Platform.desktop:
        await File(path).writeAsString(data);
        break;
      default:
        throw Exception("Unsupported platform for writing files");
    }
  }

  Future<void> delete(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        await File(path).delete();
        break;	
      default:
        throw Exception("Unsupported platform for deleting files");
    }
  }

  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    switch (_platform) {
      case _Platform.desktop:
        await Directory(path).delete(recursive: recursive);
        break;
      default:
        throw Exception("Unsupported platform for deleting directories");
    }
  }

  Future<void> createFile(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        await File(path).create(recursive: true);
        break;
      default:
        throw Exception("Unsupported platform for creating files");
    }
  }

  Future<void> createDirectory(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        await Directory(path).create(recursive: true);
        break;
      default:
        throw Exception("Unsupported platform for creating directories");
    }
  }

  Future<String> createTempDirectory(String prefix) async {
    switch (_platform) {
      case _Platform.desktop:
        return (await Directory.systemTemp.createTemp(prefix)).path;
      default:
        throw Exception("Unsupported platform for creating temp directories");
    }
  }

  Future<void> renameFile(String oldPath, String newPath) async {
    switch (_platform) {
      case _Platform.desktop:
        await File(oldPath).rename(newPath);
        break;
      default:
        throw Exception("Unsupported platform for renaming files");
    }
  }

  Future<void> renameDirectory(String oldPath, String newPath) async {
    switch (_platform) {
      case _Platform.desktop:
        await Directory(oldPath).rename(newPath);
        break;
      default:
        throw Exception("Unsupported platform for renaming directories");
    }
  }

  Future<void> copyFile(String oldPath, String newPath) async {
    switch (_platform) {
      case _Platform.desktop:
        await File(oldPath).copy(newPath);
        break;
      default:
        throw Exception("Unsupported platform for copying files");
    }
  }

  Future<bool> existsFile(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        return await File(path).exists();
      default:
        throw Exception("Unsupported platform for checking file existence");
    }
  }

  bool existsFileSync(String path) {
    switch (_platform) {
      case _Platform.desktop:
        return File(path).existsSync();
      default:
        throw Exception("Unsupported platform for checking file existence");
    }
  }

  Future<bool> existsDirectory(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        return await Directory(path).exists();
      default:
        throw Exception("Unsupported platform for checking directory existence");
    }
  }

  bool existsDirectorySync(String path) {
    switch (_platform) {
      case _Platform.desktop:
        return Directory(path).existsSync();
      default:
        throw Exception("Unsupported platform for checking directory existence");
    }
  }

  Future<bool> exists(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
      default:
        throw Exception("Unsupported platform for checking existence");
    }
  }

  bool existsSync(String path) {
    switch (_platform) {
      case _Platform.desktop:
        return FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
      default:
        throw Exception("Unsupported platform for checking existence");
    }
  }

  Stream<FileSystemEntity> list(String path, {bool recursive = false}) {
    switch (_platform) {
      case _Platform.desktop:
        return Directory(path).list(recursive: recursive);
      default:
        throw Exception("Unsupported platform for listing directories");
    }
  }

  Stream<String> listFiles(String path, {bool recursive = false}) {
    switch (_platform) {
      case _Platform.desktop:
        return Directory(path).list(recursive: recursive).where((e) => e is File).map((e) => e.path);
      default:
        throw Exception("Unsupported platform for listing files");
    }
  }
  
  Stream<String> listDirectories(String path, {bool recursive = false}) {
    switch (_platform) {
      case _Platform.desktop:
        return Directory(path).list(recursive: recursive).where((e) => e is Directory).map((e) => e.path);
      default:
        throw Exception("Unsupported platform for listing directories");
    }
  }

  Future<int> getSize(String path) async {
    switch (_platform) {
      case _Platform.desktop:
        return await File(path).length();
      default:
        throw Exception("Unsupported platform for getting file size");
    }
  }

  Future<List<String>> selectFiles({
    String? dialogTitle,
    String? initialDirectory,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    if (_platform == _Platform.web)
      throw Exception("File selection is not supported on web");
    var files = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
    );
    if (files == null)
      return [];
    return files.paths.whereType<String>().toList();
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
    String? text,
    String? initialDirectory,
    String? dialogTitle,
    List<String>? allowedExtensions,
  }) async {
    bytes ??= utf8.encode(text!);
    var file = await FilePicker.platform.saveFile(
      initialDirectory: initialDirectory,
      fileName: fileName,
      dialogTitle: dialogTitle,
      allowedExtensions: allowedExtensions,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      bytes: bytes,
    );
    if (_platform == _Platform.desktop && file != null)
      await write(file, bytes);
    return file;
  }

  void registerFile(String path, List<int> bytes) {
    switch (_platform) {
      default:
        print("Unsupported platform for getting file size");
    }
  }
}
