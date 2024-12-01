
const _masterBranch = "master";

class FServoVersion {
  final int major;
  final int minor;
  final int patch;
  final String branch;

  const FServoVersion(this.major, this.minor, this.patch, this.branch);

  static FServoVersion? parse(String version) {
    if (version.startsWith("v"))
      version = version.substring(1);
    var mainBranch = version.split("-");
    if (mainBranch.length > 2)
      return null;
    var branch = mainBranch.length == 2 ? mainBranch[1] : _masterBranch;
    var main = mainBranch[0].split(".");
    if (main.length < 3)
      return null;
    var major = int.tryParse(main[0]);
    var minor = int.tryParse(main[1]);
    var patch = int.tryParse(main[2]);
    if (major == null || minor == null || patch == null)
      return null;
    return FServoVersion(major, minor, patch, branch);
  }

  @override
  String toString() => "v$major.$minor.$patch-$branch";

  String toUiString(FServoVersion currentVersion) {
    var str = toString();
    if (this == currentVersion)
      str += " (current)";
    else if (this > currentVersion)
      str += " (new)";
    return str;
  }

  @override
  bool operator ==(Object other) {
    if (other is FServoVersion) {
      return major == other.major && minor == other.minor && patch == other.patch && branch == other.branch;
    }
    return false;
  }
  
  @override
  int get hashCode => Object.hash(major, minor, patch, branch);

  bool operator <(FServoVersion other) {
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

  bool operator >(FServoVersion other) {
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

  int compareTo(FServoVersion other) {
    if (this < other)
      return -1;
    if (this > other)
      return 1;
    return 0;
  }
}

const version = FServoVersion(1, 4, 13, "mgrr");

const branches = [_masterBranch, "mgrr"];

const branchToGameName = {
  _masterBranch: "NieR: Automata",
  "mgrr": "MGR: Revengeance",
};

const branchFirstVersionedRelease = {
  _masterBranch: FServoVersion(1, 4, 9, _masterBranch),
  "mgrr": FServoVersion(1, 4, 13, "mgrr"),
};
