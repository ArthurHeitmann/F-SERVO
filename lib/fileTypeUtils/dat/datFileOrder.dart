import 'package:path/path.dart';

import '../../utils/utils.dart';

bool Function(String) _ends(String end) {
  return (String name) => name.endsWith(end);
}
bool Function(String) _starts(String start) {
  return (String name) => name.startsWith(start);
}
bool Function(String) _eq(String eq) {
  return (String name) => name == eq;
}
bool Function(String) _re(String re) {
  var regExp = RegExp(re);
  return (String name) => regExp.hasMatch(name);
}
bool Function(String) _not(bool Function(String) f) {
  return (String name) => !f(name);
}
bool Function(String) _and(bool Function(String) f1, bool Function(String) f2) {
  return (String name) => f1(name) && f2(name);
}
bool Function(String) _or(bool Function(String) f1, bool Function(String) f2) {
  return (String name) => f1(name) || f2(name);
}

const _motI1Size = 0x10000;
const _motI2Size = 1000;
const _motOrSeqPad = _motI1Size * _motI2Size;

final List<(int, bool Function(String))> _datOrder = [
  (0, _ends(".uid")),
  (0, _ends(".uvd")),
  (0, _or(_ends(".vso"), _ends(".pso"))),
  (0, _ends(".wmb")),
  (0, _ends(".wtp")),
  (0, _ends(".eft")),
  (0, _ends(".ctx")),
  (0, _eq("CutList.bxm")),
  (0, _eq("CameraList.bxm")),
  (0, _eq("ObjList.bxm")),
  (0, _eq("PhaseInfo.bxm")),
  (0, _eq("RoomPhaseInfo.bxm")),
  (0, _eq("StateData.bxm")),
  (0, _ends("_CameraSeq.seq")),
  (0, _ends("_MoveSeq.seq")),
  (0, _ends("_EffectSeq.seq")),
  (0, _ends("_ModelControlSeq.seq")),
  (0, _ends("_ControlSeq.seq")),
  (0, _ends("_GraphicSeq.seq")),
  (0, _ends("_SeSeq.seq")),
  (0, _ends("_BgmSeq.seq")),
  (0, _ends("_VibSeq.seq")),
  (0, _ends("_sub.bxm")),
  (0, _eq("header.bxm")),
  (0, _ends(".est")),
  (0, _ends(".sst")),
  (0, _ends(".wta")),
  (0, _re(r"[0-9a-f]{4}\.d[at]t$")),
  (0, _and(_ends(".dat"), _not(_ends("_lineid_list.dat")))),
  (0, _ends("_param.bxm")),
  (0, _ends(".eff")),
  (0, _eq("_EffectArea.bxm")),
  (0, _ends("Sst.bxm")),
  (0, _ends(".pos")),
  (0, _ends(".sas")),
  (0, _ends(".sae")),
  (0, _ends(".gad")),
  (0, _ends("_battleParameter.bxm")),
  (0, _eq("_gaa.bxm")),
  (0, _ends(".lyt")),
  (0, _ends(".ly2")),
  (0, _ends(".opd")),
  (0, _ends(".scr")),
  (0, _and(_ends(".bnk"), _not(_starts("BGM")))),
  (0, _ends(".exp")),
  (0, _or(_ends("_battleParameter.bin"), _eq("_animationMap.bxm"))),
  (0, _ends(".sop")),
  (0, _eq("CutInfo.bxm")),
  (0, _ends("_attach.bxm")),
  (0, _ends("_clp.bxm")),
  (0, _ends("_clw.bxm")),
  (0, _ends("_clh.bxm")),
  (0, _ends("_freeRunFlag.bxm")),
  (0, _ends("_constant.bxm")),
  (0, _or(_starts("help"), _ends("config.bxm"))),
  (0, _eq("sndenvse.bin")),
  (0, _eq("sndenvbgm.bin")),
  (0, _eq("subtitleForVoice.bxm")),
  (0, _ends(".mcd")),
  (0, _ends(".rbd")),
  (0, _ends(".tsd")),
  (0, _ends(".mkd")),
  (0, _ends("_lineid_list.dat")),
  (0, _eq("lod.bxm")),
  (0, _eq("SeHitAtf.bxm")),
  (0, _eq("ListenerPreset.bxm")),
  (0, _eq("EffectSeAttrBullet.bxm")),
  (0, _ends(".brd")),
  (0, _starts("pageno_list_")),
  (0, _ends(".rad")),
  (0, _eq("radarmapinfo.bxm")),
  (0, _starts("combolist_")),
  (0, _starts("subtitleForVoiceDLC")),
  (0, _ends(".trg")),
  (0, _ends(".tgs")),
  (0, _ends("_pos.bxm")),
  (0, _ends("_sca.bxm")),
  (0, _ends("_sca_col.bxm")),
  (0, _ends("_sca_em.bxm")),
  (0, _ends("_psca.bxm")),
  (0, _ends("_ChainBreak.bxm")),
  (0, _eq("_ItemRate.bxm")),
  (0, _ends("_Gimmick.bxm")),
  (0, _ends("_QTEPos.bxm")),
  (0, _ends("_UseRank.bxm")),
  (0, _ends("_ObjectivePos.bxm")),
  (0, _ends("_NeedList.bxm")),
  (0, _ends("_ItemInsta.bxm")),
  (0, _ends("_Param.bxm")),
  (0, _ends("_EnemySet.bxm")),
  (0, _ends("_SoftEvent.bxm")),
  (0, _ends("_col.hkx")),
  (0, _ends("_DRInfo.bxm")),
  (0, _ends("_colLink.bxm")),
  (0, _ends("_roomNeighborArea.bxm")),
  (0, _ends("_roomOption.bxm")),
  (0, _ends("_path.bin")),
  (0, _ends("_path00.bin")),
  (0, _ends("_path_navi.bin")),
  (0, _ends("_esc.bxm")),
  (0, _ends("_EnemyWay00.bxm")),
  (0, _ends(".cut.bxm")),
  (0, _and(_ends(".bnk"), _starts("BGM"))),
  (0, _ends(".gil")),
  (0, _ends(".evn")),
  (0, _eq("Customize_Info.bxm")),
  (0, _eq("ShaderArea.bxm")),
  (0, _ends(".vcd")),
  (0, _ends(".vca")),
  (0, _ends("_territory.bxm")),
  (0, _ends("antiqueScroll.bxm")),
  (0, _ends("battleresult.bxm")),
  (0, _eq("VR_Mission_Data.bxm")),
  (0, _starts("credit_")),
  (0, _eq("liftInfo.bxm")),
  (_motOrSeqPad, _or(_ends(".mot"), _ends(".seq"))),
  (0, _ends(".syn")),
  (0, _eq("CamParam.bxm")),
  (0, _eq("situation.bxm")),
  (0, _eq("debrisExplodeParameter.bxm")),
  (0, _eq("datsuSetTable.bxm")),
  (0, _eq("cameraConstantParameter.bxm")),
  (0, _eq("effectCollision.bxm")),
  (0, _eq("stageresult.bxm")),
  (0, _re(r"battleresult\w{2}\.bxm")),
  (0, _eq("uiRadarMap.bxm")),
  (0, _eq("RadioModelParam.bxm")),
  (0, _eq("itemlist.bxm")),
  (0, _eq("ItemGenericParam.bxm")),
  (0, _eq("ItemCureParam.bxm")),
  (0, _eq("combolist.bxm")),
  (0, _and(_ends(".wtb"), _not(_starts("mess")))),
  (0, _and(_ends(".wtb"), _starts("mess"))),
];

int _motKey(String name, int pad) {
  // em0100_2030.mot
  var numStr = name.split(".").firstOrNull?.split("_").lastOrNull;
  if (numStr == null)
    return pad;
  return ((int.tryParse(numStr, radix: 16) ?? 0) + 1) * _motI1Size + pad;
}
int _seqKey(String name, int pad) {
  // em0100_2040_2_seq.bxm
  var noExt = name.split(".").firstOrNull;
  if (noExt == null)
    return pad;
  var numParts = noExt.split("_");
  if (numParts.length != 3)
    return pad;
  var i1 = int.tryParse(numParts[1], radix: 16);
  var i2 = int.tryParse(numParts[2]);
  if (i1 == null || i2 == null)
    return pad;
  i1 += 1;
  i2 += 1;
  return i1 * _motI2Size + i2 + pad;
}

int _nameKey(String name, {bool orderMotSeq = true}) {
  int offset = 0;
  for (var (i, (pad, test)) in _datOrder.indexed) {
    offset += i;
    if (test(name)) {
      if (orderMotSeq && pad == _motOrSeqPad) {
        if (name.endsWith(".mot"))
          return _motKey(name, offset);
        if (name.endsWith(".seq"))
          return _seqKey(name, offset);
      }
      return offset;
    }
    offset += pad;
  }
  return offset;
}

class _File {
  final String name;
  final String path;
  int? _key;
  int get key => _key ??= _nameKey(name);

  _File(this.path) : name = basename(path);
}

List<String> _sortDatFilesBestGuess(List<_File> files) {
  var indexedFiles = files.indexed.toList();
  indexedFiles.sort((a, b) {
    var keyCmp = a.$2.key.compareTo(b.$2.key);
    if (keyCmp != 0)
      return keyCmp;
    var nameCmp = a.$2.name.compareTo(b.$2.name);
    if (nameCmp != 0)
      return nameCmp;
    return a.$1.compareTo(b.$1);
  });
  return indexedFiles.map((a) => a.$2.path).toList();
}

List<String> _sortDatFilesWithOriginalOrder(List<_File> files, List<String> originalOrder) {
  List<_File> knownFiles = [];
  for (var originalFile in originalOrder) {
    var file = files.where((f) => f.name == originalFile).firstOrNull;
    if (file != null)
      knownFiles.add(file);
  }
  List<_File> unknownFiles = [];
  for (var file in files) {
    if (!originalOrder.contains(file.name))
      unknownFiles.add(file);
  }

  var sortedFiles = knownFiles;
  for (var insertFile in unknownFiles) {
    bool inserted = false;
    for (var (i, file) in sortedFiles.indexed) {
      if (insertFile.key < file.key) {
        sortedFiles.insert(i, insertFile);
        inserted = true;
        break;
      }
    }
    if (!inserted)
      sortedFiles.add(insertFile);
  }
  return sortedFiles.map((file) => file.path).toList();
}

List<String> sortDatFiles(List<String> paths, List<String>? originalOrder) {
  if (originalOrder != null)
    paths = deduplicate(paths);
  var files = paths.map((path) => _File(path)).toList();
  if (originalOrder == null)
    return _sortDatFilesBestGuess(files);
  return _sortDatFilesWithOriginalOrder(files, originalOrder);
}

int countDatFilesOrderErrors(List<String> files) {
  var keys = files.map((f) => _nameKey(f, orderMotSeq: false)).toList();
  int errors = 0;
  for (int i = 1; i < keys.length; i++) {
    if (keys[i] < keys[i - 1])
      errors += 1;
  }
  return errors;
}
