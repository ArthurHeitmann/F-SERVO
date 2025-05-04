
import 'dart:typed_data';

class VirtualEntity {
  String name;
  String path;

  VirtualEntity(this.name, this.path);
}

class VirtualFile extends VirtualEntity {
  Uint8List bytes;

  VirtualFile(super.name, super.path, this.bytes);
}

class VirtualFolder extends VirtualEntity {
  final List<VirtualEntity> children;
  
  VirtualFolder(super.name, super.path, this.children);

  VirtualEntity? getChild(String name) {
    return children.where((e) => e.name == name).firstOrNull;
  }
}
