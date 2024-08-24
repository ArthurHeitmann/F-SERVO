class WwiseSwitchOrState {
  final int id;
  final String uuid;
  final String name;

  const WwiseSwitchOrState(this.id, this.uuid, this.name);
}

class WwiseSwitchOrStateGroup {
  final int id;
  final String uuid;
  final String name;
  final List<WwiseSwitchOrState> children;

  const WwiseSwitchOrStateGroup(this.id, this.uuid, this.name, this.children);
}
