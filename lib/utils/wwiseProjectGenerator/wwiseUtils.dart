
import '../../fileTypeUtils/audio/bnkIO.dart';
import '../../fileTypeUtils/audio/wemIdsToNames.dart';
import 'elements/hierarchyBaseElements.dart';
import 'wwiseProjectGenerator.dart';

void addWwiseGroupUsage<S>(Map<S, Set<int>> map, S groupName, int id) {
  if (id == 0)
    return;
  if (!map.containsKey(groupName))
    map[groupName] = {};
  map[groupName]!.add(id);
}

String wwiseIdToStr(int id, { bool alwaysIncludeId = false, String? fallbackPrefix }) {
  var name = wemIdsToNames[id];
  if (name != null)
    return name + (alwaysIncludeId ? " ($id)" : "");
  if (fallbackPrefix != null)
    return "$fallbackPrefix $id";
  return id.toString();
}

String wwiseNullId = "{00000000-0000-0000-0000-000000000000}";

int _getHash(List<int> nameBytes) {
  int hash = 2166136261;

  for (int namebyte in nameBytes) {
    hash = hash * 16777619;
    hash = hash ^ namebyte;
    hash = hash & 0xFFFFFFFF;
  }
  return hash;
}

int fnvHash(String name) {
  return _getHash(name.toLowerCase().codeUnits);
}

double _meterInfoToBarLengthMs(BnkAkMeterInfo meterInfo) {
  return 60000 / meterInfo.fTempo * meterInfo.uNumBeatsPerBar / meterInfo.uBeatValue * 4;
}

double _meterInfoToBeatLengthMs(BnkAkMeterInfo meterInfo) {
  return 60000 / meterInfo.fTempo / meterInfo.uBeatValue * 4;
}

double _meterInfoToNoteLengthMs(BnkAkMeterInfo meterInfo) {
  return 60000 / meterInfo.fTempo * 4;
}

List<({int preset, double Function(BnkAkMeterInfo) calcLength})> _availableLengthConfigs = [
  (preset: 0,	calcLength: (meter) => 0),
  (preset: 50,	calcLength: (meter) => _meterInfoToBarLengthMs(meter) * 4),
  (preset: 51,	calcLength: (meter) => _meterInfoToBarLengthMs(meter) * 2),
  (preset: 52,	calcLength: (meter) => _meterInfoToBarLengthMs(meter) * 1),
  (preset: 53,	calcLength: (meter) => _meterInfoToBeatLengthMs(meter) * 1),
  (preset: 54,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/1),
  (preset: 55,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/2),
  (preset: 56,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/4),
  (preset: 57,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/8),
  (preset: 64,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/16),
  (preset: 67,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/32),
  (preset: 58,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/2 /3*2),
  (preset: 59,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/4 /3*2),
  (preset: 60,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/8 /3*2),
  (preset: 65,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/16 /3*2),
  (preset: 68,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/32 /3*2),
  (preset: 61,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/2 * 1.5),
  (preset: 62,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/4 * 1.5),
  (preset: 63,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/8 * 1.5),
  (preset: 66,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/16 * 1.5),
  (preset: 69,	calcLength: (meter) => _meterInfoToNoteLengthMs(meter) * 1/32 * 1.5),
];

int determineMeterPreset(BnkAkMeterInfo meterInfo, double lengthMs) {
  for (var config in _availableLengthConfigs) {
    if ((config.calcLength(meterInfo) - lengthMs).abs() < 0.01)
      return config.preset;
  }
  throw ArgumentError("Could not determine meter preset for length $lengthMs");
}

String getCommonString(List<String> strings) {
  if (strings.isEmpty)
    return "";
  if (strings.length == 1)
    return strings.first;
  var minLen = strings.map((s) => s.length).reduce((a, b) => a < b ? a : b);
  for (int i = 0; i < minLen; i++) {
    if (strings.map((s) => s[i]).toSet().length > 1)
      return strings.first.substring(0, i);
  }
  return strings.first.substring(0, minLen);
}

String makeElementName(WwiseProjectGenerator project, {required int id, required String category, int parentId = 0, String? name, List<int>? childIds, bool addId = false}) {
  String? parentPrefix;
  if (parentId != 0 && project.options.namePrefix) {
    var parent = project.hircChunkById<BnkHircChunkBase>(parentId);
    int? stateId;
    if (parent is BnkSoundSwitch) {
      for (var switchPackage in parent.switches) {
        if (switchPackage.nodeIDs.any((nodeId) => nodeId == id)) {
          stateId = switchPackage.ulSwitchID;
          break;
        }
      }
    } else if (parent is BnkMusicSwitch) {
      stateId = parent.pAssocs
        .where((e) => e.nodeID == id)
        .firstOrNull
        ?.switchID;
    }
    if (stateId != null) {
      var stateName = wemIdsToNames[stateId];
      if (stateName != null)
        parentPrefix = "[$stateName] ";
    }
  }

  if (name == null && childIds != null && childIds.isNotEmpty) {
    var childNames = childIds
      .map((id) => project.lookupElement(idFnv: id))
      .whereType<WwiseHierarchyElement>()
      .map((e) => e.name.split(" ").first)
      .whereType<String>()
      .toList();
    if (childNames.isNotEmpty) {
      var commonName = getCommonString(childNames.toList());
      if (commonName.length >= 3) {
        name = commonName.replaceAll(RegExp(r"_+$"), "");
      }
    }
  }
  name ??= wemIdsToNames[id];
  name ??= category;
  if (parentPrefix != null)
    name = parentPrefix + name;
  if (addId && project.options.nameId)
    name += " ($id)";
  return project.makeName(name, parentId);
}
