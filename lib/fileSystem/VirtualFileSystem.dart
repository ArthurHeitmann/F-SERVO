
import 'dart:math';
import 'dart:typed_data';

import 'VirtualEntities.dart';

class VirtualFileSystem {
  final root = VirtualFolder("", "", []);
  final Map<String, VirtualEntity> _entities = {};
  final _random = Random();
  static const _tempDir = "\$";

  VirtualFileSystem() {
    _entities[root.name] = root;
  }

  VirtualFile getFile(String path) {
    path = _normalizePath(path);
    var file = _entities[path];
    if (file == null)
      throw Exception("File not found: $path");
    if (file is! VirtualFile)
      throw Exception("$path is a folder, not a file");
    return file;
  }

  Uint8List read(String path) {
    path = _normalizePath(path);
    var file = _entities[path];
    if (file == null)
      throw Exception("File not found: $path");
    if (file is! VirtualFile)
      throw Exception("$path is a folder, not a file");
    return file.bytes.asUnmodifiableView();
  }

  void write(String path, List<int> bytes) {
    path = _normalizePath(path);
    Uint8List buffer;
    if (bytes is Uint8List) {
      buffer = bytes;
    } else {
      buffer = Uint8List.fromList(bytes);
    }
    _setBytes(path, buffer);
  }

  int getFileSize(String path) {
    path = _normalizePath(path);
    var file = _entities[path];
    if (file == null)
      throw Exception("File not found: $path");
    if (file is! VirtualFile)
      throw Exception("$path is a folder, not a file");
    return file.bytes.length;
  }

  void createFile(String path) {
    path = _normalizePath(path);
    _setBytes(path, Uint8List(0));
  }

  void createFolder(String path) {
    path = _normalizePath(path);
    var (parts, name) = _splitPath(path);
    var folder = _getOrMakeFolder(parts);
    var newFolder = VirtualFolder(name, path, []);
    folder.children.add(newFolder);
    _entities[path] = newFolder;
  }

  String createTempFolder(String prefix) {
    var path = "$_tempDir/${prefix}_${_random.nextInt(1000000).toRadixString(16)}";
    createFolder(path);
    return path;
  }

  void deleteFile(String path) {
    path = _normalizePath(path);
    _entities.remove(path);
    var (parts, name) = _splitPath(path);
    var folder = _entities[parts.join("/")];
    if (folder == null)
      throw Exception("Folder not found: ${parts.join("/")}");
    if (folder is! VirtualFolder)
      throw Exception("${parts.join("/")} is a file, not a folder");
    folder.children.removeWhere((e) => e.name == name);
  }

  void deleteFolder(String path, {required bool recursive}) {
    path = _normalizePath(path);
    var folder = _entities[path];
    if (folder == null)
      throw Exception("Folder not found: $path");
    if (folder is! VirtualFolder)
      throw Exception("$path is a file, not a folder");
    if (recursive) {
      for (var child in folder.children) {
        if (child is VirtualFile) {
          deleteFile(child.path);
        } else if (child is VirtualFolder) {
          deleteFolder(child.path, recursive: true);
        }
      }
    }
    else if (folder.children.isNotEmpty) {
      throw Exception("Folder is not empty: $path");
    }
    var parentPath = _parentPath(path);
    var parentFolder = _entities[parentPath];
    if (parentFolder == null)
      throw Exception("Parent folder not found: $parentPath");
    if (parentFolder is! VirtualFolder)
      throw Exception("$parentPath is a file, not a folder");
    parentFolder.children.removeWhere((e) => e.name == folder.name);
    _entities.remove(path);
  }

  void copyFile(String src, String dest) {
    src = _normalizePath(src);
    dest = _normalizePath(dest);
    var srcBuffer = read(src);
    write(dest, srcBuffer);
  }

  void moveFile(String src, String dest) {
    copyFile(src, dest);
    deleteFile(src);
  }

  List<VirtualEntity> list(String path) {
    path = _normalizePath(path);
    var folder = _entities[path];
    if (folder == null)
      throw Exception("Folder not found: $path");
    if (folder is! VirtualFolder)
      throw Exception("$path is a file, not a folder");
    return folder.children;
  }

  bool existsFile(String path) {
    path = _normalizePath(path);
    return _entities.containsKey(path) && _entities[path] is VirtualFile;
  }

  bool existsFolder(String path) {
    path = _normalizePath(path);
    return _entities.containsKey(path) && _entities[path] is VirtualFolder;
  }

  bool exists(String path) {
    path = _normalizePath(path);
    return _entities.containsKey(path);
  }

  void _setBytes(String path, Uint8List bytes) {
    var file = _entities[path];
    if (file == null) {
      var (parts, name) = _splitPath(path);
      var folder = _getOrMakeFolder(parts);
      var newFile = VirtualFile(name, path, bytes);
      folder.children.add(newFile);
      _entities[path] = newFile;
    } else {
      if (file is! VirtualFile)
        throw Exception("$path is a folder, not a file");
      file.bytes = bytes;
    }
  }

  VirtualFolder _getOrMakeFolder(List<String> parts) {
    var current = root;
    for (var (i, part) in parts.indexed) {
      var existing = current.children.where((e) => e.name == part).firstOrNull;
      if (existing != null) {
        if (existing is! VirtualFolder)
          throw Exception("$part is a file, not a folder");
        current = existing;
      } else {
        var path = parts.sublist(0, i + 1).join("/");
        var newFolder = VirtualFolder(part, path, []);
        current.children.add(newFolder);
        _entities[path] = newFolder;
        current = newFolder;
      }
    }
    return current;
  }

  (List<String>, String) _splitPath(String path) {
    var parts = _split(path);
    var name = parts.last;
    var folderParts = parts.sublist(0, parts.length - 1);
    return (folderParts, name);
  }

  List<String> _split(String path) {
    return path.split("/").where((e) => e.isNotEmpty).toList();
  }

  _parentPath(String path) {
    var parts = _split(path);
    if (parts.isEmpty) return root.name;
    return parts.sublist(0, parts.length - 1).join("/");
  }

  String _normalizePath(String path) {
    return path.split("/").where((e) => e.isNotEmpty).map((e) => e.trim()).join("/");
  }
}
