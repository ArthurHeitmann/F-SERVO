
class Version {
  final int major;
  final int minor;
  final int patch;
  
  const Version(this.major, this.minor, this.patch);
  
  static Version? parse(String version) {
    var parts = version.split(".");
    if (parts.length != 3)
      return null;
    if (!parts.every((p) => int.tryParse(p) != null))
      return null;
    return Version(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2])
    );
  }

  @override
  String toString() => "$major.$minor.$patch";

  @override
  bool operator ==(Object other) {
    if (other is! Version)
      return false;
    return major == other.major && minor == other.minor && patch == other.patch;
  }

  @override
  int get hashCode => major.hashCode ^ minor.hashCode ^ patch.hashCode;

  bool operator <(Version other) {
    if (major < other.major)
      return true;
    if (major > other.major)
      return false;
    if (minor < other.minor)
      return true;
    if (minor > other.minor)
      return false;
    return patch < other.patch;
  }

  bool operator <=(Version other) {
    if (major < other.major)
      return true;
    if (major > other.major)
      return false;
    if (minor < other.minor)
      return true;
    if (minor > other.minor)
      return false;
    return patch <= other.patch;
  }

  bool operator >(Version other) {
    if (major > other.major)
      return true;
    if (major < other.major)
      return false;
    if (minor > other.minor)
      return true;
    if (minor < other.minor)
      return false;
    return patch > other.patch;
  }

  bool operator >=(Version other) {
    if (major > other.major)
      return true;
    if (major < other.major)
      return false;
    if (minor > other.minor)
      return true;
    if (minor < other.minor)
      return false;
    return patch >= other.patch;
  }
}
