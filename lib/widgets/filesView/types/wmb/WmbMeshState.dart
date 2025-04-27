
class WmbMeshState {
  final String name;
  final int id;
  bool _isVisible;
  final List<WmbMeshState> children = [];
  final void Function(int, bool) _setModelVisible;

  WmbMeshState(this.name, this.id, this._isVisible, this._setModelVisible);

  void addChild(List<String> path, int id, bool isVisible) {
    if (path.length == 1) {
      children.add(WmbMeshState(path[0], id, isVisible, _setModelVisible));
      return;
    }
    var child = children.where((c) => c.name == path[0]).firstOrNull;
    if (child == null) {
      child = WmbMeshState(path[0], -1, isVisible, _setModelVisible);
      children.add(child);
    }
    child.addChild(path.sublist(1), id, isVisible);
  }

  set isVisible(bool? value) {
    _isVisible = value!;
    if (children.isEmpty)
      _setModelVisible(id, value);
    for (var child in children)
      child.isVisible = value;
  }

  bool? get isVisible {
    if (children.isEmpty) {
      return _isVisible;
    }
    var visibleChildren = children.where((c) => c.isVisible == true);
    var invisibleChildren = children.where((c) => c.isVisible == false);
    if (visibleChildren.isNotEmpty && invisibleChildren.isNotEmpty) {
      return null;
    }
    return visibleChildren.isNotEmpty;
  }
}
