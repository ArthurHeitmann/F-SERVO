

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/dat/datExtractor.dart';
import '../../../fileTypeUtils/mcd/mcdIO.dart';
import '../../../fileTypeUtils/uid/uidIO.dart';
import '../../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../events/statusInfo.dart';
import '../../hasUuid.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import '../openFilesManager.dart';
import '../../../fileSystem/FileSystem.dart';

class UidFileData extends OpenFileData {
  UidFile? uid;
  final List<UidEntryData> entries = [];
  final selectedEntry = ValueNotifier<UidEntryData?>(null);
  Map<int, String> mcdNames = {};

  UidFileData(super.name, super.path, { super.secondaryName })
    : super(type: FileType.uid, icon: Icons.widgets);

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var bytes = await ByteDataWrapper.fromFile(path);
    uid = UidFile.read(bytes);
    entries.clear();
    for (var entry in uid!.entries1) {
      entries.add(UidEntryData.fromEntry(entry, uuid));
    }

    try {
      mcdNames.clear();
      var endingLength = "0001.uid".length;
      var baseName = basename(path);
      baseName = baseName.substring(0, baseName.length - endingLength);
      var mcdPath = join(dirname(path), "mess$baseName.mcd");
      await _loadMcdNames(mcdPath);
      var otherBaseNames = entries.where((e) => e.mcdData != null).map((e) => e.mcdData!.file.value).toSet();
      otherBaseNames.remove(baseName);
      for (var baseName in otherBaseNames) {
        var datName = "ui_${baseName}_us.dat";
        var datPath = join(dirname(dirname(dirname(path))), datName);
        var datDir = join(dirname(dirname(path)), datName);
        if (!await FS.i.existsDirectory(datDir))
          await extractDatFiles(datPath);
        var mcdPath = join(datDir, "mess$baseName.mcd");
        if (!await FS.i.existsFile(mcdPath))
          continue;
        await _loadMcdNames(mcdPath);
      }
    } on Exception catch (e, st) {
      messageLog.add("$e\n$st");
      messageLog.add("Failed to load MCD names");
    }

    await super.load();
  }

  Future<void> _loadMcdNames(String mcdPath) async {
    if (!await FS.i.existsFile(mcdPath))
      return;
    var mcdBytes = await ByteDataWrapper.fromFile(mcdPath);
    var mcd = McdFile.read(mcdBytes);
    var symbolsMap = mcd.makeSymbolsMap();
    for (var event in mcd.events) {
      var paragraph = event.message.paragraphs[0];
      var str = paragraph.lines
        .map((line) => line.encodeAsString(paragraph.fontId, symbolsMap))
        .join("  ");
      mcdNames[event.id] = str;
    }
  }

  @override
  Future<void> save() async {
    if (loadingState.value != LoadingState.loaded)
      return;

    for (var (i, entry) in entries.indexed) {
      entry.apply(uid!.entries1[i]);
    }
    var bytes = await ByteDataWrapper.fromFile(path);
    uid!.write(bytes);
    await backupFile(path);
    await bytes.save(path);

    await super.save();
  }

  @override
  void dispose() {
    selectedEntry.dispose();
    for (var entry in entries) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var data = UidFileData(name.value, path);
    for (var entry in entries) {
      data.entries.add(entry.takeSnapshot() as UidEntryData);
    }
    return data;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as UidFileData;
    for (var i = 0; i < entries.length; i++) {
      entries[i].restoreWith(data.entries[i]);
    }
  }
}

class UidEntryData with HasUuid implements Undoable {
  final OpenFileId fileId;
  late final VectorProp translation;
  late final VectorProp rotation;
  late final VectorProp scale;
  late final VectorProp rgb;
  late final NumberProp alpha;
  UidMcdEntryData? mcdData;
  UidUvdEntryData? uvdData;

  UidEntryData(this.fileId);

  UidEntryData.fromEntry(UidEntry1 entry, this.fileId) {
    translation = VectorProp(entry.translation.toList(), fileId: fileId);
    rotation = VectorProp(entry.rotation.toList(), fileId: fileId);
    scale = VectorProp(entry.scale.toList(), fileId: fileId);
    rgb = VectorProp(entry.rgb.toList(), fileId: fileId);
    alpha = NumberProp(entry.alpha, false, fileId: fileId);
    mcdData = UidMcdEntryData.fromData1(entry.data1, fileId);
    uvdData = UidUvdEntryData.fromData1(entry.data1, fileId);
    translation.addListener(_onPropChange);
    rotation.addListener(_onPropChange);
    scale.addListener(_onPropChange);
    rgb.addListener(_onPropChange);
    alpha.addListener(_onPropChange);
  }

  void apply(UidEntry1 entry) {
    entry.translation = Vector(translation[0].value.toDouble(), translation[1].value.toDouble(), translation[2].value.toDouble());
    entry.rotation = Vector(rotation[0].value.toDouble(), rotation[1].value.toDouble(), rotation[2].value.toDouble());
    entry.scale = Vector(scale[0].value.toDouble(), scale[1].value.toDouble(), scale[2].value.toDouble());
    entry.rgb = Vector(rgb[0].value.toDouble(), rgb[1].value.toDouble(), rgb[2].value.toDouble());
    entry.alpha = alpha.value.toDouble();
    mcdData?.apply(entry.data1!);
    uvdData?.apply(entry.data1!);
  }

  void dispose() {
    translation.dispose();
    rotation.dispose();
    scale.dispose();
    rgb.dispose();
    alpha.dispose();
    mcdData?.dispose();
    uvdData?.dispose();
  }

  void _onPropChange() {
    var file = areasManager.fromId(fileId);
    file?.setHasUnsavedChanges(true);
  }

  @override
  bool historyEnabled = true;

  @override
  Undoable takeSnapshot() {
    var data = UidEntryData(fileId);
    data.translation = translation.takeSnapshot() as VectorProp;
    data.rotation = rotation.takeSnapshot() as VectorProp;
    data.scale = scale.takeSnapshot() as VectorProp;
    data.rgb = rgb.takeSnapshot() as VectorProp;
    data.alpha = alpha.takeSnapshot() as NumberProp;
    if (mcdData != null)
      data.mcdData = mcdData!.takeSnapshot() as UidMcdEntryData;
    if (uvdData != null)
      data.uvdData = uvdData!.takeSnapshot() as UidUvdEntryData;
    return data;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as UidEntryData;
    translation.restoreWith(data.translation);
    rotation.restoreWith(data.rotation);
    scale.restoreWith(data.scale);
    rgb.restoreWith(data.rgb);
    alpha.restoreWith(data.alpha);
    if (mcdData != null)
      mcdData!.restoreWith(data.mcdData!);
    if (uvdData != null)
      uvdData!.restoreWith(data.uvdData!);
  }
}

class UidMcdEntryData with HasUuid implements Undoable {
  final OpenFileId fileId;
  final StringProp file;
  final HexProp id;

  UidMcdEntryData(String file, int id, this.fileId) :
    file = StringProp(file, fileId: fileId),
    id = HexProp(id, fileId: fileId) {
    this.file.addListener(_onPropChange);
    this.id.addListener(_onPropChange);
  }

  static UidMcdEntryData? fromData1(UidData1? data1, OpenFileId file) {
    if (data1 == null)
      return null;
    if (!data1.mightBeMcdData())
      return null;
    return UidMcdEntryData(
      data1.getMcdFileName()!,
      data1.getMcdEntryId()!,
      file,
    );
  }

  void apply(UidData1 data1) {
    data1.setMcdFileName(file.value);
    data1.setMcdEntryId(id.value);
  }

  void dispose() {
    file.dispose();
    id.dispose();
  }

  void _onPropChange() {
    var file = areasManager.fromId(fileId);
    file?.setHasUnsavedChanges(true);
  }
  
  @override
  bool historyEnabled = true;
  
  @override
  Undoable takeSnapshot() {
    return UidMcdEntryData(file.value, id.value, fileId);
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as UidMcdEntryData;
    file.value = data.file.value;
    id.value = data.id.value;
  }
}

class UidUvdEntryData with HasUuid implements Undoable {
  final OpenFileId fileId;
  final NumberProp width;
  final NumberProp height;
  final HexProp texId;
  final HexProp uvdId;

  UidUvdEntryData(double width, double height, int texId, int uvdId, this.fileId) :
    width = NumberProp(width, false, fileId: fileId),
    height = NumberProp(height, false, fileId: fileId),
    texId = HexProp(texId, fileId: fileId),
    uvdId = HexProp(uvdId, fileId: fileId) {
    this.width.addListener(_onPropChange);
    this.height.addListener(_onPropChange);
    this.texId.addListener(_onPropChange);
    this.uvdId.addListener(_onPropChange);
  }

  static UidUvdEntryData? fromData1(UidData1? data1, OpenFileId file) {
    if (data1 == null)
      return null;
    if (!data1.mightBeUvdData())
      return null;
    return UidUvdEntryData(
      data1.getUvdWidth()!,
      data1.getUvdHeight()!,
      data1.getUvdTexId()!,
      data1.getUvdId()!,
      file,
    );
  }

  void apply(UidData1 data1) {
    data1.setUvdWidth(width.value.toDouble());
    data1.setUvdHeight(height.value.toDouble());
    data1.setUvdTexId(texId.value);
    data1.setUvdId(uvdId.value);
  }

  void dispose() {
    width.dispose();
    height.dispose();
    texId.dispose();
    uvdId.dispose();
  }

  void _onPropChange() {
    var file = areasManager.fromId(fileId);
    file?.setHasUnsavedChanges(true);
  }

  @override
  bool historyEnabled = true;

  @override
  Undoable takeSnapshot() {
    return UidUvdEntryData(width.value.toDouble(), height.value.toDouble(), texId.value, uvdId.value, fileId);
  }

  @override
  void restoreWith(Undoable snapshot) {
    var data = snapshot as UidUvdEntryData;
    width.value = data.width.value;
    height.value = data.height.value;
    texId.value = data.texId.value;
    uvdId.value = data.uvdId.value;
  }
}

const messCoreNames = {
  0x2FF4957D: "MAVERICK SECURITY CONSULTING, INC.",
  0x58F3A5EB: "DESPERADO ENFORCEMENT, LLC",
  0x41FAF451: "WORLD MARSHAL, INC.",
  0x36FDC4C7: "SOLIS SPACE & AERONAUTICS",
  0x689820EA: "MAVERICK",
  0x1F9F107C: "DESPERADO",
  0x069641C6: "WORLD MARSHAL",
  0x71917150: "SOLIS",
  0x58DE93CD: "HEAD UNIT",
  0x2FD9A35B: "LEG GEAR <R>",
  0x36D0F2E1: "LEG GEAR <L>",
  0x41D7C277: "TAIL UNIT",
  0x43269992: "HUMAN",
  0x3421A904: "CYBORG",
  0x2D28F8BE: "UNMANNED GEAR",
  0x5A2FC828: "CIVILIAN",
  0x40E20605: "FILE R-00: GUARD DUTY",
  0x37E53693: "FILE R-01: COUP D'\u00c9TAT",
  0x2EEC6729: "FILE R-02: RESEARCH FACILITY",
  0x59EB57BF: "FILE R-03: MILE HIGH",
  0x478FC21C: "FILE R-04: HOSTILE TAKEOVER",
  0x3088F28A: "FILE R-05: ESCAPE FROM DENVER",
  0x2981A330: "FILE R-06: BADLANDS SHOWDOWN",
  0x5E8693A6: "FILE R-07: ASSASSINATION ATTEMPT",
  0x4E398E37: "DL-STORY-01: JETSTREAM",
  0x393EBEA1: "DL-STORY-02: BLADE WOLF",
  0x59F93744: "FILE E-00: THE HERO",
  0x43568FF0: "NONE",
  0x275C68D3: "Cyborg (Standard)",
  0x3E553969: "Cyborg (Custom)",
  0x495209FF: "Cyborg (Heavily Armed)",
  0x57369C5C: "Slider",
  0x2031ACCA: "Tripod",
  0x3938FD70: "Mastiff",
  0x4E3FCDE6: "Irving",
  0x5E80D077: "Raptor",
  0x2987E0E1: "Vodomjerka",
  0x49406904: "LQ-84i",
  0x3E475992: "Fenrir",
  0x274E0828: "Hammerhead",
  0x504938BE: "M18A1",
  0x4E2DAD1D: "M1143",
  0x392A9D8B: "Unmanned Gun Turret",
  0x2023CC31: "Gun Camera",
  0x5724FCA7: "Metal Gear RAY (Modified)",
  0x479BE136: "Grad",
  0x309CD1A0: "Mistral",
  0x626D3AC7: "Body Double (Mistral)",
  0x156A0A51: "Monsoon",
  0x0C635BEB: "Body Double (Monsoon)",
  0x7B646B7D: "Sundowner",
  0x6500FEDE: "Body Double (Sundowner)",
  0x1207CE48: "Samuel Rodrigues",
  0x0B0E9FF2: "Metal Gear Excelsus",
  0x7C09AF64: "Andrey Dolzaev",
  0x6CB6B2F5: "Raiden",
  0x1BB18263: "Boris Vyacheslavovich Popov",
  0x7B760B86: "Kevin Washington",
  0x0C713B10: "Courtney Collins",
  0x15786AAA: "Wilhelm Voigt",
  0x627F5A3C: "Blade Wolf",
  0x7C1BCF9F: "Sunny Emmerich",
  0x0B1CFF09: "George",
  0x1215AEB3: "Cyborg Cop",
  0x65129E25: "Khamsin",
  0x75AD83B4: "Steven Armstrong",
  0x02AAB322: "DLC 3",
  0x34379D41: "DLC 4",
  0x4330ADD7: "DLC 5",
  0x4256BE23: "UNKNOWN",
  0x35518EB5: "CYBORG",
  0x2C58DF0F: "C. CYBORG",
  0x5B5FEF99: "H. CYBORG",
  0x453B7A3A: "SLIDER",
  0x323C4AAC: "TRIPOD",
  0x2B351B16: "MASTIFF",
  0x5C322B80: "IRVING",
  0x4C8D3611: "RAPTOR",
  0x3B8A0687: "VODOMJERKA",
  0x5B4D8F62: "LQ-84I",
  0x2C4ABFF4: "FENRIR",
  0x3543EE4E: "HAMMERHEAD",
  0x4244DED8: "M18A1",
  0x5C204B7B: "M1143",
  0x2B277BED: "GUN TURRET",
  0x322E2A57: "GUN CAMERA",
  0x45291AC1: "MG RAY <MOD.>",
  0x55960750: "GRAD",
  0x229137C6: "MISTRAL",
  0x7060DCA1: "B.D. MISTRAL",
  0x0767EC37: "MONSOON",
  0x1E6EBD8D: "B.D. MONSOON",
  0x69698D1B: "SUNDOWNER",
  0x770D18B8: "B.D. SUNDOWNER",
  0x000A282E: "SAM",
  0x19037994: "MG EXCELSUS",
  0x6E044902: "DOLZAEV",
  0x7EBB5493: "RAIDEN",
  0x09BC6405: "BORIS",
  0x697BEDE0: "KEVIN",
  0x1E7CDD76: "COURTNEY",
  0x07758CCC: "DOKTOR",
  0x7072BC5A: "WOLF",
  0x6E1629F9: "SUNNY",
  0x1911196F: "GEORGE",
  0x001848D5: "C. COP",
  0x771F7843: "KHAMSIN",
  0x67A065D2: "SENATOR",
  0x10A75544: "DLC 3",
  0x263A7B27: "DLC 4",
  0x513D4BB1: "DLC 5",
  0x51B12CE5: "Custom Cyborg Body",
  0x48B87D5F: "Custom Cyborg Body (Red)",
  0x3FBF4DC9: "Custom Cyborg Body (Blue)",
  0x21DBD86A: "Custom Cyborg Body (Yellow)",
  0x56DCE8FC: "Custom Cyborg Body (Desperado Ver.)",
  0x4FD5B946: "Custom Cyborg Body (White Armor)",
  0x38D289D0: "Custom Cyborg Body (Inferno Armor)",
  0x286D9441: "Custom Cyborg Body (Commando Armor)",
  0x5F6AA4D7: "Color Type D",
  0x3FAD2D32: "High-Frequency Machete",
  0x48AA1DA4: "High-Frequency Blade",
  0x51A34C1E: "Standard Cyborg Body",
  0x26A47C88: "Suit",
  0x38C0E92B: "Mariachi Uniform",
  0x4FC7D9BD: "Infinite Wig A",
  0x56CE8807: "Infinite Wig B",
  0x21C9B891: "Blade Mode Wig",
  0x3176A500: "Artificial Skin",
  0x46719596: "Original Cyborg Body",
  0x14807EF1: "Gray Fox",
  0x63874E67: "High-Frequency Blade",
  0x7A8E1FDD: "High-Frequency Long Sword",
  0x0D892F4B: "Stun Blade",
  0x13EDBAE8: "Armor Breaker",
  0x64EA8A7E: "High-Frequency Wooden Sword",
  0x7DE3DBC4: "High-Frequency Murasama Blade",
  0x0AE4EB52: "FOX Blade",
  0x1A5BF6C3: "Pole-Arm \"L'\u00c9tranger\"",
  0x6D5CC655: "Tactical Sai \"Dystopia\"",
  0x0D9B4FB0: "Pincer Blades \"Bloodlust\"",
  0x7A9C7F26: "Strength Enhancement (1)",
  0x63952E9C: "Strength Enhancement (2)",
  0x14921E0A: "Strength Enhancement (3)",
  0x0AF68BA9: "Strength Enhancement (4)",
  0x7DF1BB3F: "Strength Enhancement (5)",
  0x64F8EA85: "Absorption Enhancement (1)",
  0x13FFDA13: "Absorption Enhancement (2)",
  0x0340C782: "Absorption Enhancement (3)",
  0x7447F714: "Absorption Enhancement (4)",
  0x42DAD977: "Absorption Enhancement (5)",
  0x35DDE9E1: "Energy Enhancement (1)",
  0x2CD4B85B: "Energy Enhancement (2)",
  0x5BD388CD: "Energy Enhancement (3)",
  0x45B71D6E: "Energy Enhancement (4)",
  0x32B02DF8: "Energy Enhancement (5)",
  0x2BB97C42: "Stun Blade Enhancement (1)",
  0x5CBE4CD4: "Stun Blade Enhancement (2)",
  0x4C015145: "Stun Blade Enhancement (3)",
  0x3B0661D3: "Stun Blade Enhancement (4)",
  0x5BC1E836: "Stun Blade Enhancement (5)",
  0x2CC6D8A0: "Armor Breaker Enhancement (1)",
  0x35CF891A: "Armor Breaker Enhancement (2)",
  0x42C8B98C: "Armor Breaker Enhancement (3)",
  0x5CAC2C2F: "Armor Breaker Enhancement (4)",
  0x2BAB1CB9: "Armor Breaker Enhancement (5)",
  0x32A24D03: "Wooden Blade Inhibitor (1)",
  0x45A57D95: "Wooden Blade Inhibitor (2)",
  0x551A6004: "Wooden Blade Inhibitor (3)",
  0x221D5092: "Wooden Blade Inhibitor (4)",
  0x70ECBBF5: "Wooden Blade Inhibitor (5)",
  0x07EB8B63: "Wooden Blade Effect Enhancement (1)",
  0x1EE2DAD9: "Wooden Blade Effect Enhancement (2)",
  0x69E5EA4F: "Wooden Blade Effect Enhancement (3)",
  0x77817FEC: "Wooden Blade Effect Enhancement (4)",
  0x00864F7A: "Wooden Blade Effect Enhancement (5)",
  0x198F1EC0: "FOX Blade Effect Enhancement",
  0x6E882E56: "-",
  0x7E3733C7: "-",
  0x09300351: "-",
  0x69F78AB4: "-",
  0x1EF0BA22: "Pole-Arm Effect Enhancement (1)",
  0x07F9EB98: "Pole-Arm Effect Enhancement (2)",
  0x70FEDB0E: "Pole-Arm Effect Enhancement (3)",
  0x6E9A4EAD: "Pole-Arm Effect Enhancement (4)",
  0x199D7E3B: "Pole-Arm Effect Enhancement (5)",
  0x00942F81: "Sai Range Extension (1)",
  0x77931F17: "Sai Range Extension (2)",
  0x672C0286: "Sai Range Extension (3)",
  0x102B3210: "Sai Range Extension (4)",
  0x6E6F967B: "Sai Range Extension (5)",
  0x1968A6ED: "-",
  0x0061F757: "-",
  0x7766C7C1: "-",
  0x69025262: "Endurance Upgrade (1)",
  0x1E0562F4: "Endurance Upgrade (2)",
  0x070C334E: "Endurance Upgrade (3)",
  0x700B03D8: "Endurance Upgrade (4)",
  0x60B41E49: "Endurance Upgrade (5)",
  0x17B32EDF: "Fuel Cell Upgrade (1)",
  0x7774A73A: "Fuel Cell Upgrade (2)",
  0x007397AC: "Fuel Cell Upgrade (3)",
  0x197AC616: "Fuel Cell Upgrade (4)",
  0x6E7DF680: "Fuel Cell Upgrade (5)",
  0x70196323: "Quick Draw",
  0x071E53B5: "Aerial Parry",
  0x1E17020F: "Lightning Strike",
  0x69103299: "Thunder Strike",
  0x79AF2F08: "Sky High",
  0x0EA81F9E: "Sweep Kick",
  0x27747644: "Stormbringer",
  0x507346D2: "Marches du ciel",
  0x497A1768: "Lumi\u00e8re du ciel",
  0x3E7D27FE: "Cercle de l'ange",
  0x2019B25D: "Turbulence",
  0x571E82CB: "Down Burst",
  0x4E17D371: "Rocket-Propelled Grenade",
  0x3910E3E7: "Surface-to-Air Homing Missile",
  0x29AFFE76: "Grenade",
  0x5EA8CEE0: "Red Phosphorus Grenade",
  0x3E6F4705: "Jamming Grenade",
  0x49687793: "Electromagnetic Grenade",
  0x50612629: "3D Photo Frame",
  0x276616BF: "Cardboard Box",
  0x3902831C: "Drum Can",
  0x4E05B38A: "-",
  0x570CE230: "Electrolyte Pack",
  0x200BD2A6: "Repair Nanopaste",
  0x30B4CF37: "-",
  0x47B3FFA1: "Nano Repair Unit (Damaged)",
  0x154214C6: "Nano Repair Unit",
  0x62452450: "Nano Repair Unit (Damaged)",
  0x7B4C75EA: "Nano Repair Unit",
  0x0C4B457C: "Holographic Memory Chip (Small)",
  0x122FD0DF: "Holographic Memory Chip (Med)",
  0x6528E049: "Holographic Memory Chip (Large)",
  0x7C21B1F3: "LIFE Tank",
  0x0B268165: "Electrolyte Tank",
  0x1B999CF4: "Left Hand",
  0x6C9EAC62: "Falling Lightning",
  0x0C592587: "-",
  0x7B5E1511: "-",
  0x625744AB: "-",
  0x1550743D: "Terminal",
  0x0B34E19E: "Access Code",
  0x7C33D108: "Optional Mission",
  0x653A80B2: "VR Mission",
  0x123DB024: "Item",
  0x0282ADB5: "Security Gate",
  0x75859D23: "Artificial Hair (Brown)",
  0x4318B340: "Artificial Hair (Blond)",
  0x341F83D6: "Artificial Hair (Black)",
  0x2D16D26C: "Artificial Hair (Blue)",
  0x5A11E2FA: "Men In Boxes",
  0x44757759: "Item Box",
  0x337247CF: "Data Storage",
  0x2A7B1675: "Defensive Offense",
  0x5D7C26E3: "Access Code (Red)",
  0x4DC33B72: "Access Code (Blue)",
  0x3AC40BE4: "Access Code (Yellow)",
  0x5A038201: "Heat Knife",
  0x2D04B297: "High-Frequency Chainsaw",
  0x340DE32D: "Endurance Upgrade",
  0x430AD3BB: "Fuel Cell Upgrade",
  0x5D6E4618: "Access Code",
  0x2A69768E: "-",
  0x33602734: "-",
  0x446717A2: "-",
  0x54D80A33: "-",
  0x23DF3AA5: "-",
  0x712ED1C2: "-",
  0x0629E154: "-",
  0x1F20B0EE: "-",
  0x68278078: "-",
  0x764315DB: "-",
  0x0144254D: "-",
  0x184D74F7: "-",
  0x6F4A4461: "-",
  0x7FF559F0: "-",
  0x4DFC6CA4: "CUSTOM BODY",
  0x54F53D1E: "CUSTOM BODY <RED>",
  0x23F20D88: "CUSTOM BODY <BLUE>",
  0x3D96982B: "CUSTOM BODY <YEL>",
  0x4A91A8BD: "CUSTOM BODY <DESP>",
  0x5398F907: "WHITE ARMOR",
  0x249FC991: "INFERNO ARMOR",
  0x3420D400: "COMMANDO ARMOR",
  0x4327E496: "COLOR TYPE D",
  0x23E06D73: "HF MACHETE",
  0x54E75DE5: "HF BLADE",
  0x4DEE0C5F: "STANDARD BODY",
  0x3AE93CC9: "SUIT",
  0x248DA96A: "MARIACHI UNIFORM",
  0x538A99FC: "INFINITE WIG A",
  0x4A83C846: "INFINITE WIG B",
  0x3D84F8D0: "BLADE MODE WIG",
  0x2D3BE541: "ARTIFICIAL SKIN",
  0x5A3CD5D7: "ORIGINAL BODY",
  0x08CD3EB0: "GRAY FOX",
  0x7FCA0E26: "HF BLADE",
  0x66C35F9C: "HF LONG SWORD",
  0x11C46F0A: "STUN BLADE",
  0x0FA0FAA9: "ARMOR BREAKER",
  0x78A7CA3F: "HF WOODEN SWORD",
  0x61AE9B85: "HF MURASAMA BLADE",
  0x16A9AB13: "FOX BLADE",
  0x0616B682: "POLE-ARM",
  0x71118614: "SAI",
  0x11D60FF1: "PINCER BLADES",
  0x66D13F67: "STRENGTH + 1",
  0x7FD86EDD: "STRENGTH + 2",
  0x08DF5E4B: "STRENGTH + 3",
  0x16BBCBE8: "STRENGTH + 4",
  0x61BCFB7E: "STRENGTH + 5",
  0x78B5AAC4: "ABSORPTION + 1",
  0x0FB29A52: "ABSORPTION + 2",
  0x1F0D87C3: "ABSORPTION + 3",
  0x680AB755: "ABSORPTION + 4",
  0x5E979936: "ABSORPTION + 5",
  0x2990A9A0: "ENERGY + 1",
  0x3099F81A: "ENERGY + 2",
  0x479EC88C: "ENERGY + 3",
  0x59FA5D2F: "ENERGY + 4",
  0x2EFD6DB9: "ENERGY + 5",
  0x37F43C03: "STUN BLADE + 1",
  0x40F30C95: "STUN BLADE + 2",
  0x504C1104: "STUN BLADE + 3",
  0x274B2192: "STUN BLADE + 4",
  0x478CA877: "STUN BLADE + 5",
  0x308B98E1: "ARMOR BREAKER + 1",
  0x2982C95B: "ARMOR BREAKER + 2",
  0x5E85F9CD: "ARMOR BREAKER + 3",
  0x40E16C6E: "ARMOR BREAKER + 4",
  0x37E65CF8: "ARMOR BREAKER + 5",
  0x2EEF0D42: "WOODEN BLADE - 1",
  0x59E83DD4: "WOODEN BLADE - 2",
  0x49572045: "WOODEN BLADE - 3",
  0x3E5010D3: "WOODEN BLADE - 4",
  0x6CA1FBB4: "WOODEN BLADE - 5",
  0x1BA6CB22: "WOODEN BLADE + 1",
  0x02AF9A98: "WOODEN BLADE + 2",
  0x75A8AA0E: "WOODEN BLADE + 3",
  0x6BCC3FAD: "WOODEN BLADE + 4",
  0x1CCB0F3B: "WOODEN BLADE + 5",
  0x05C25E81: "FOX BLADE +",
  0x72C56E17: "-",
  0x627A7386: "-",
  0x157D4310: "-",
  0x75BACAF5: "-",
  0x02BDFA63: "POLE-ARM + 1",
  0x1BB4ABD9: "POLE-ARM + 2",
  0x6CB39B4F: "POLE-ARM + 3",
  0x72D70EEC: "POLE-ARM + 4",
  0x05D03E7A: "POLE-ARM + 5",
  0x1CD96FC0: "SAI RANGE + 1",
  0x6BDE5F56: "SAI RANGE + 2",
  0x7B6142C7: "SAI RANGE + 3",
  0x0C667251: "SAI RANGE + 4",
  0x7222D63A: "SAI RANGE + 5",
  0x0525E6AC: "-",
  0x1C2CB716: "-",
  0x6B2B8780: "-",
  0x754F1223: "ENDURANCE + 1",
  0x024822B5: "ENDURANCE + 2",
  0x1B41730F: "ENDURANCE + 3",
  0x6C464399: "ENDURANCE + 4",
  0x7CF95E08: "ENDURANCE + 5",
  0x0BFE6E9E: "FUEL CELL + 1",
  0x6B39E77B: "FUEL CELL + 2",
  0x1C3ED7ED: "FUEL CELL + 3",
  0x05378657: "FUEL CELL + 4",
  0x7230B6C1: "FUEL CELL + 5",
  0x6C542362: "QUICK DRAW",
  0x1B5313F4: "AERIAL PARRY",
  0x025A424E: "LIGHTNING STRIKE",
  0x755D72D8: "THUNDER STRIKE",
  0x65E26F49: "SKY HIGH",
  0x12E55FDF: "SWEEP KICK",
  0x3B393605: "STORMBRINGER",
  0x4C3E0693: "MARCHES DU CIEL",
  0x55375729: "LUMI\u00c8RE DU CIEL",
  0x223067BF: "CERCLE DE L'ANGE",
  0x3C54F21C: "TURBULENCE",
  0x4B53C28A: "DOWN BURST",
  0x525A9330: "ROCKET LAUNCHER",
  0x255DA3A6: "HOMING MISSILE",
  0x35E2BE37: "GRENADE",
  0x42E58EA1: "RP. GRENADE",
  0x22220744: "JAM. GRENADE",
  0x552537D2: "EM. GRENADE",
  0x4C2C6668: "3D PHOTO FRAME",
  0x3B2B56FE: "C. BOX",
  0x254FC35D: "DRUM CAN",
  0x5248F3CB: "-",
  0x4B41A271: "ELECTROLYTE PACK",
  0x3C4692E7: "REPAIR NANOPASTE",
  0x2CF98F76: "-",
  0x5BFEBFE0: "REPAIR UNIT <DMG>",
  0x090F5487: "REPAIR UNIT",
  0x7E086411: "REPAIR UNIT <DMG>",
  0x670135AB: "REPAIR UNIT",
  0x1006053D: "HOLO-CHIP <S>",
  0x0E62909E: "HOLO-CHIP <M>",
  0x7965A008: "HOLO-CHIP <L>",
  0x606CF1B2: "LIFE TANK",
  0x176BC124: "ELECTROLYTE TANK",
  0x07D4DCB5: "L. HAND",
  0x70D3EC23: "FALLING LIGHTNING",
  0x101465C6: "-",
  0x67135550: "-",
  0x7E1A04EA: "-",
  0x091D347C: "TERMINAL",
  0x1779A1DF: "ACCESS CODE",
  0x607E9149: "OPTIONAL MISSION",
  0x7977C0F3: "VR MISSION",
  0x0E70F065: "ITEM",
  0x1ECFEDF4: "SECURITY GATE",
  0x69C8DD62: "BROWN HAIR",
  0x5F55F301: "BLOND HAIR",
  0x2852C397: "BLACK HAIR",
  0x315B922D: "BLUE HAIR",
  0x465CA2BB: "MIB",
  0x58383718: "ITEM BOX",
  0x2F3F078E: "DATA STORAGE",
  0x36365634: "DEFENSIVE OFFENSE",
  0x413166A2: "CODE <RED>",
  0x518E7B33: "CODE <BLUE>",
  0x26894BA5: "CODE <YELLOW>",
  0x464EC240: "HEAT KNIFE",
  0x3149F2D6: "HF CHAINSAW",
  0x2840A36C: "ENDURANCE +",
  0x5F4793FA: "FUEL CELL +",
  0x41230659: "CODE",
  0x362436CF: "-",
  0x2F2D6775: "-",
  0x582A57E3: "-",
  0x48954A72: "-",
  0x3F927AE4: "-",
  0x6D639183: "-",
  0x1A64A115: "-",
  0x036DF0AF: "-",
  0x746AC039: "-",
  0x6A0E559A: "-",
  0x1D09650C: "-",
  0x040034B6: "-",
  0x73070420: "-",
  0x63B819B1: "-",
  0x1BA9E2BF: "VR MISSION",
  0x6CAED229: "ID",
  0x75A78393: "MIB",
  0x02A0B305: "DATA STORAGE",
  0x1CC426A6: "UNLOCKED",
  0x6BC31630: "COMPLETE",
  0x72192D23: "LOADING",
  0x051E1DB5: ".",
  0x1C174C0F: "SAVING",
  0x6B107C99: "CHECKPOINT",
  0x7574E93A: "-",
  0x0273D9AC: "ASSIST",
  0x30A7018D: "ZANDATSUS",
  0x2EC3942E: "PARTS",
  0x59C4A4B8: "KILLS",
  0x5072E893: "BONUS BP",
  0x47B251E0: "COMBAT LOG",
  0x3E6EE944: "HITS",
  0x2A8D7382: "AUGMENT",
  0x5D8A4314: "MODE",
  0x448312AE: "ANALYZED",
  0x33842238: "/",
  0x2DE0B79B: "REVERT",
  0x5AE7870D: "RESETTING COMBAT LOG",
  0x43EED6B7: "WEAPON ID AUTHENTICATED",
  0x34E9E621: "BLADE OSCILLATOR ENGAGED",
  0x2456FBB0: "XIFF SYSTEM ENGAGED",
  0x5351CB26: "[CHECKING FUEL CELLS]",
  0x339642C3: "[CHECKING BODY STATUS]",
  0x44917255: "[CHECKING ARMAMENTS]",
  0x5D9823EF: "[LOADING TERRAIN DATA]",
  0x2A9F1379: "[LOADING COMBAT DATA]",
  0x5987831B: "OBJECTIVE",
  0x53BF3002: "HOLD",
  0x24B80094: "Blade Mode",
  0x3DB1512E: "Ninja Run",
  0x4AB661B8: "Use Sub-weapon",
  0x54D2F41B: "Switch Lock-on",
  0x23D5C48D: "Camera Control",
  0x3ADC9537: "Free Blade Mode",
  0x4DDBA5A1: "-",
  0x5D64B830: "-",
  0x2A6388A6: "-",
  0x4AA40143: "CAPTIONS",
  0x3DA331D5: "ON",
  0x24AA606F: "OFF",
  0x53AD50F9: "AUTO",
  0x7E8A0089: "BASIC CONTROLS",
  0x67835133: "Ripper Mode",
  0x108461A5: "Blade Mode",
  0x0EE0F406: "Switch Lock-on",
  0x79E7C490: "-",
  0x60EE952A: "Strong Attack",
  0x17E9A5BC: "Light Attack",
  0x0756B82D: "Sub-weapon",
  0x705188BB: "Jump",
  0x1096015E: "Move",
  0x679131C8: "Ninja Run",
  0x7E986072: "Camera Control",
  0x099F50E4: "Camera Reset",
  0x17FBC547: "BLADE MODE CONTROLS",
  0x60FCF5D1: "Vertical Slice",
  0x79F5A46B: "Horizontal Slice",
  0x0EF294FD: "Use Sub-weapon",
  0x1E4D896C: "Free Blade Mode",
  0x694AB9FA: "HOLD",
  0x3BBB529D: "+",
  0x4CBC620B: "Change Sub-weapon",
  0x55B533B1: "AR Mode",
  0x22B20327: "Use Item",
  0x3CD69684: "-",
  0x4BD1A612: "Parry",
  0x52D8F7A8: "Execution",
  0x25DFC73E: "Step Attack",
  0x3560DAAF: "Blade Mode",
  0x4267EA39: "Dash",
  0x22A063DC: "Taunt",
  0x55A7534A: "Blade Mode",
  0x4CAE02F0: "Dash",
  0x3BA93266: "Free Blade Mode",
  0x25CDA7C5: "-",
  0x52CA9753: "-",
  0x4BC3C6E9: "-",
  0x3CC4F67F: "-",
  0x2C7BEBEE: "-",
  0x0F1F5F8B: "YES",
  0x78186F1D: "NO",
  0x61113EA7: "OK",
  0x4699A324: "CONFIRM",
  0x319E93B2: "CANCEL",
  0x2897C208: "SELECT",
  0x5F90F29E: "BACK",
  0x41F4673D: "FORWARD",
  0x36F357AB: "DEFAULTS",
  0x2FFA0611: "USE",
  0x58FD3687: "CHANGE",
  0x48422B16: "SELECT",
  0x3F451B80: "SWITCH SCREEN",
  0x5F829265: "COPY",
  0x2885A2F3: "OVERWRITE",
  0x318CF349: "DELETE",
  0x468BC3DF: "DETAILS",
  0x58EF567C: "START",
  0x2FE866EA: "EQUIP",
  0x36E13750: "UNEQUIP",
  0x41E607C6: "EXIT CUSTOMIZE",
  0x51591A57: "PURCHASE",
  0x265E2AC1: "ROTATE",
  0x74AFC1A6: "ZOOM IN",
  0x03A8F130: "ZOOM OUT",
  0x1AA1A08A: "MOVE",
  0x6DA6901C: "ZOOMED VIEW",
  0x73C205BF: "CHANGE ZOOM",
  0x04C53529: "ENHANCEMENTS",
  0x1DCC6493: "CHANGE STORAGE DEVICE",
  0x6ACB5405: "RANKING RESULT",
  0x7A744994: "GAME RESULT",
  0x0D737902: "PLAY IN SUCCESSION",
  0x1D76C546: "[b/C-A]",
  0x6A71F5D0: "[b/C-B]",
  0x7378A46A: "[b/C-B]",
  0x047F94FC: "[b/C-A]",
  0x1A1B015F: "[b/C-Y]",
  0x6D1C31C9: "[b/C-X]",
  0x74156073: "[b/C-RB]",
  0x031250E5: "[b/C-RT]",
  0x13AD4D74: "[b/C-LB]",
  0x64AA7DE2: "[b/C-LT]",
  0x046DF407: "[b/C-DPad]",
  0x736AC491: "[b/C-DPad-UD]",
  0x6A63952B: "[b/C-DPad-LR]",
  0x1D64A5BD: "[b/C-DPad-Up]",
  0x0300301E: "[b/C-DPad-Down]",
  0x74070088: "[b/C-DPad-Left]",
  0x6D0E5132: "[b/C-DPad-Right]",
  0x1A0961A4: "[b/C-RStick]",
  0x0AB67C35: "[b/C-RStick-Press]",
  0x7DB14CA3: "[b/C-LStick]",
  0x2F40A7C4: "[b/C-LStick-Press]",
  0x58479752: "[b/C-Start]",
  0x414EC6E8: "[b/C-Back]",
  0x3649F67E: "[b/C-Arrow-Up]",
  0x282D63DD: "[b/C-Arrow-Down]",
  0x5F2A534B: "[b/C-Arrow-Left]",
  0x462302F1: "[b/C-Arrow-Right]",
  0x31243267: "[c/0x8003:127]",
  0x219B2FF6: "[c/0x8003:28]",
  0x569C1F60: "[c/0x8003:29]",
  0x365B9685: "[c/0x8003:30]",
  0x415CA613: "[c/0x8003:31]",
  0x5855F7A9: "[b/B-Defensive-Offense]",
  0x2F52C73F: "[b/B-Heavy-Attack]",
  0x3136529C: "[c/0x8003:113]",
  0x5E9D010D: "[b/K-Enter]",
  0x299A319B: "[b/K-Esc]",
  0x30936021: "[b/K-Up]",
  0x479450B7: "[b/K-Down]",
  0x59F0C514: "[b/K-Left]",
  0x2EF7F582: "[b/K-Right]",
  0x37FEA438: "[c/0x8003:38]",
  0x40F994AE: "[c/0x8003:39]",
  0x5046893F: "[b/K-Z]",
  0x2741B9A9: "[b/K-X]",
  0x4786304C: "[b/K-E]",
  0x308100DA: "[b/K-Ctrl]",
  0x29885160: "[b/K-C]",
  0x5E8F61F6: "[b/K-Shift]",
  0x40EBF455: "[c/0x8003:46]",
  0x37ECC4C3: "[c/0x8003:47]",
  0x2EE59579: "[c/0x8003:48]",
  0x59E2A5EF: "[b/K-V]",
  0x495DB87E: "[b/K-Num4]",
  0x3E5A88E8: "[b/K-Num3]",
  0x6CAB638F: "[b/K-Up][b/K-Down][b/K-Left][b/K-Right]",
  0x1BAC5319: "[b/K-Up][b/K-Down]",
  0x02A502A3: "[b/K-Left][b/K-Right]",
  0x0D28C0E3: "[c/0x8003:52]",
  0x46741346: "[c/0x8003:53]",
  0x40E061E8: "[c/0x8003:54]",
  0x6BB72CB6: "Options updated.  Would you like to proceed with these changes?",
  0x1CB01C20: "Language options cannot be changed in-game.  Please change language options by selecting   OPTIONS on the Title Screen.",
  0x05B94D9A: "Return to default settings?",
  0x72BE7D0C: "Equipment changed.  Would you like to proceed with these changes?",
  0x6CDAE8AF: "Equipment changed.",
  0x1BDDD839: "Customize Raiden's body?",
  0x02D48983: "Save?",
  0x75D3B915: "Save data copied.",
  0x656CA484: "Overwrite save data?",
  0x126B9412: "Save data overwriten.",
  0x72AC1DF7: "Delete save data?",
  0x05AB2D61: "Save data deleted.",
  0x1CA27CDB: "Play Tutorial?",
  0x6BA54C4D: "This game features an Auto-Save function.  Please do not exit the game or turn off the   system while the save indicator is displayed.",
  0x75C1D9EE: "Exit game?",
  0x02C6E978: "Exit game?  You will lose all unsaved progress.",
  0x1BCFB8C2: "This enhancement will expend BP.  Proceed with enhancement?",
  0x6CC88854: "This customization will expend BP.  Proceed with customization?",
  0x7C7795C5: "Exit Customize Screen?",
  0x0B70A553: "Exit the Customize Screen and proceed to the  next chapter of the game?",
  0x59814E34: "No game data found.   METAL GEAR RISING requires  that game data be installed.     Installing game data.  Do not switch off the power  while the HDD access indicator is flashing.",
  0x2E867EA2: "There is not enough free space on the HDD.  At least xxxx MB of free space are  required to install game data.   Please quit the game via the PS button and  create enough free space.",
  0x378F2F18: "The title will now install game data.  Do not switch off the power  while the HDD access indicator is flashing.",
  0x40881F8E: "Installation cancelled.  Incomplete game data was created.  Please re-install if you would like to use game data.",
  0x5EEC8A2D: "Installation complete.",
  0x29EBBABB: "Installation failed.  Please exit the game via the PS button and  delete the incomplete game data.",
  0x30E2EB01: "METAL GEAR RISING game data is corrupted.  Please exit the game via the PS button and  delete the incomplete game data.",
  0x47E5DB97: "METAL GEAR RISING game data is corrupted.  To use game data please exit via the PS button and  delete the corrupted data then select INSTALL.    Play the game without using this game data?",
  0x575AC606: "METAL GEAR RISING game data is corrupted.  METAL GEAR RISING requires  that game data be installed.    The title will now install game data.  Do not switch off the power  while the HDD access indicator is flashing.",
  0x205DF690: "This save data was created by a different user  and cannot be used.  Overwrite this save data and start a new game?",
  0x409A7F75: "This save data was created by a different user  and therefore cannot be copied.",
  0x379D4FE3: "Exit game and connect to the PlayStation\u00aeStore?",
  0x2E941E59: "Exit game?",
  0x59932ECF: "Connect to the PlayStation\u00aeStore?",
  0x47F7BB6C: "Save?  This operation would normally save  your progress.  However, in this demo version,   no data will actually be saved.",
  0x30F08BFA: "Proceeding start a new game, resetting your  game progress and game results. Your VR  Mission, Collection, and Customization data  will remain.   Start a new game?",
  0x29F9DA40: "Switch to motion control?",
  0x5EFEEAD6: "-",
  0x4E41F747: "-",
  0x3946C7D1: "-",
  0x0FDBE9B2: "-",
  0x78DCD924: "-",
  0x61D5889E: "Restart from last checkpoint.",
  0x16D2B808: "Save current game status and  latest checkpoint data?",
  0x08B62DAB: "Restart from last checkpoint.",
  0x7FB11D3D: "You will lose all unsaved progress.  Return to Title Screen?",
  0x66B84C87: "You will lose all unsaved progress.  Restart from last checkpoint?",
  0x11BF7C11: "You will lose all unsaved progress.  Restart mission?",
  0x01006180: "Activate Easy Assist mode to allow for  automatic direction input when parrying?  Note: This mode is recommended for   those who are both new to action games  and want to play on a lower difficulty.",
  0x76075116: "Changing difficulty settings will   deactivate Easy Assist mode.",
  0x16C0D8F3: "Begin VR Missions.   When you exit the VR Missions, you will   restart Story Mode from the last checkpoint.",
  0x61C7E865: "Begin Customization.   When you exit Customization, you will   restart Story Mode from the last checkpoint.",
  0x78CEB9DF: "You will lose any unsaved progress.  Return to the VR Missions select screen?",
  0x0FC98949: "Exit VR Missions and   return to Story Mode?",
  0x11AD1CEA: "Exit Customize Screen and   return to Story Mode?",
  0x66AA2C7C: "Starting a New Game will reset your game progress,   results, and character customizations.   Your VR Mission and Collection data will remain.   Are you sure you want to start a New Game?",
  0x7FA37DC6: "Online service is disabled on your  PlayStation\u00aeNetwork account  due to parental control restrictions.",
  0x08A44D50: "Unable to connect to Xbox LIVE Marketplace.",
  0x181B50C1: "No network connection.  Unable to connect to Xbox LIVE Marketplace.",
  0x4AEABBA6: "This game features an Auto-Save function.  Please do not exit the game or turn off the   console while the save indicator is displayed.",
  0x53E3EA1C: "Exit game and connect to the Xbox LIVE Marketplace?",
  0x24E4DA8A: "Return to Title Screen?",
  0x3A804F29: "If you select a chapter,  the latest checkpoint data will be lost.  Are you sure you want to proceed?",
  0x4D877FBF: "You are currently not signed into a gamer profile.  You will be unable to save.",
  0x548E2E05: "Save failed.",
  0x23891E93: "Impossible to connect to Xbox LIVE Marketplace,  as you are currently not signed into Xbox LIVE.",
  0x33360302: "Return to the VR Missions select screen?",
  0x44313394: "No storage device has been selected.  You will not be able to save.",
  0x24F6BA71: "DL-VR Missions have been added.  These missions may now be accessed by  selecting VR MISSIONS on the Title Screen.",
  0x53F18AE7: "\"DL-Story-01: Jetstream\" has been added.  It may now be accessed by selecting  STORY on the Title Screen.",
  0x4AF8DB5D: "Activate VR Mission?",
  0x3DFFEBCB: "Exit VR Missions and   return to Story Mode?",
  0x239B7E68: "\"DL-Story-02: Blade Wolf\" has been added.  It may now be accessed by selecting  STORY on the Title Screen.",
  0x549C4EFE: " ",
  0x4D951F44: "Downloadable content not found.  Before selecting Continue, missing   downloadable content must be re-downloaded.",
  0x3A922FD2: "Downloadable content not found.   Some chapters are currently unplayable.  To select these chapters, missing  downloadable content must be re-downloaded.",
  0x2A2D3243: "A required storage device has been removed.   Unable to read download content data.  Please attach the storage device used   to save your download content data.",
  0x5D2A02D5: "A required storage device has been removed.   Unable to read download content data.  Game will end and return to the Title Screen.",
  0x236EA6BE: "Download content data is corrupted.",
  0x54699628: "Storage device has been removed.   Please attach the required storage device.",
  0x4D60C792: "Storage device has been removed.   Game will end and return to the Title Screen.",
  0x3A67F704: "Proceeding will cause current Story Mode checkpoint   data to be lost. Are you sure you want to proceed?",
  0x240362A7: "-",
  0x53045231: "Proceeding will reset your current game progress   and game results from DL-Story-01: Jetstream.   Current Story Mode checkpoint data will also be lost.   Are you sure you want to proceed?",
  0x4A0D038B: "Proceeding will reset your current game progress   and game results from DL-Story-02: Blade Wolf.  Current Story Mode checkpoint data will also be lost.  Are you sure you want to proceed?",
  0x3D0A331D: "Settings have not been saved. Proceed?",
  0x2DB52E8C: "This key has already been assigned a command.  Please select a different key.",
  0x5AB21E1A: "Key configuration has been updated.  Apply changes?",
  0x3A7597FF: "Graphics options have been updated.  Apply changes?",
  0x4D72A769: "Return to default settings?",
  0x352A05CD: "R1",
  0x422D355B: "R2",
  0x5B2464E1: "L1",
  0x2C235477: "L2",
  0x3247C1D4: "RB",
  0x4540F142: "RT",
  0x5C49A0F8: "LB",
  0x2B4E906E: "LT",
  0x29FFD5A5: "Eliminate all enemies via  Hunt Kills.",
  0x034AE5BF: "An updated version of Raiden's cyborg body  firmware that allows faster, more detailed  feedback to be delivered to his brain synapses.  This detailed neural feedback allows Raiden to",
  0x744DD529: "freely sidestep enemy attacks in any direction  and effectively counter their aggression.",
  0x34FB86DA: "BLADE OSCILLATOR ENGAGED",
  0x59DA6671: "CUTSCENES",
  0x40D337CB: "SCENE",
  0x7042C4D3: "LEFT CLICK",
  0x694B9569: "RIGHT CLICK",
  0x1E4CA5FF: "WHEEL CLICK",
  0x1D3C8054: "ESC",
  0x0435D1EE: "F1",
  0x7332E178: "F2",
  0x6D5674DB: "F3",
  0x1A51444D: "F4",
  0x035815F7: "F5",
  0x745F2561: "F6",
  0x64E038F0: "F7",
  0x13E70866: "F8",
  0x73208183: "F9",
  0x0427B115: "F10",
  0x1D2EE0AF: "F11",
  0x6A29D039: "F12",
  0x744D459A: "`",
  0x034A750C: "1",
  0x1A4324B6: "2",
  0x6D441420: "3",
  0x7DFB09B1: "4",
  0x0AFC3927: "5",
  0x580DD240: "6",
  0x2F0AE2D6: "7",
  0x3603B36C: "8",
  0x410483FA: "9",
  0x5F601659: "0",
  0x286726CF: "-",
  0x316E7775: "=",
  0x466947E3: "BACKSPACE",
  0x56D65A72: "TAB",
  0x21D16AE4: "Q",
  0x4116E301: "W",
  0x3611D397: "E",
  0x2F18822D: "R",
  0x581FB2BB: "T",
  0x467B2718: "Y",
  0x317C178E: "U",
  0x28754634: "I",
  0x5F7276A2: "O",
  0x4FCD6B33: "P",
  0x38CA5BA5: "[",
  0x0E5775C6: "]",
  0x79504550: "\\",
  0x605914EA: "CAPS LOCK",
  0x175E247C: "A",
  0x093AB1DF: "S",
  0x7E3D8149: "D",
  0x6734D0F3: "F",
  0x1033E065: "G",
  0x008CFDF4: "H",
  0x778BCD62: "J",
  0x174C4487: "K",
  0x604B7411: "L",
  0x794225AB: ";",
  0x0E45153D: " ",
  0x1021809E: "ENTER",
  0x6726B008: "SHIFT",
  0x7E2FE1B2: "Z",
  0x0928D124: "X",
  0x1997CCB5: "C",
  0x6E90FC23: "V",
  0x3C611744: "B",
  0x4B6627D2: "N",
  0x526F7668: "M",
  0x256846FE: ",",
  0x3B0CD35D: ".",
  0x4C0BE3CB: "/",
  0x5502B271: "CTRL",
  0x220582E7: "WINDOWS",
  0x32BA9F76: "ALT",
  0x45BDAFE0: "SPACE",
  0x257A2605: "MENU",
  0x527D1693: "PRINT SCREEN",
  0x4B744729: "SCROLL LOCK",
  0x3C7377BF: "PAUSE",
  0x2217E21C: "INSERT",
  0x5510D28A: "HOME",
  0x4C198330: "PAGE UP",
  0x3B1EB3A6: "DELETE",
  0x2BA1AE37: "END",
  0x5CA69EA1: "PAGE DOWN",
  0x22E23ACA: "\u2191",
  0x55E50A5C: "\u2190",
  0x4CEC5BE6: "\u2193",
  0x3BEB6B70: "\u2192",
  0x258FFED3: "NUM LOCK",
  0x5288CE45: "NUM /",
  0x4B819FFF: "NUM *",
  0x3C86AF69: "NUM -",
  0x2C39B2F8: "NUM 7",
  0x5B3E826E: "NUM 8",
  0x3BF90B8B: "NUM 9",
  0x4CFE3B1D: "NUM 4",
  0x55F76AA7: "NUM 5",
  0x22F05A31: "NUM 6",
  0x3C94CF92: "NUM +",
  0x4B93FF04: "NUM 1",
  0x529AAEBE: "NUM 2",
  0x259D9E28: "NUM 3",
  0x352283B9: "NUM 0",
  0x4225B32F: "NUM .",
  0x6BF9DAF5: ":",
  0x1CFEEA63: " ",
  0x05F7BBD9: "^",
  0x72F08B4F: "R SHIFT",
  0x6C941EEC: "R ALT",
  0x1B932E7A: "R CTRL",
  0x029A7FC0: "NUM ENTER",
  0x194567B5: "L Click",
  0x004C360F: "R Click",
  0x774B0699: "Wheel Click",
  0x743B2332: "Esc",
  0x6D327288: "F1",
  0x1A35421E: "F2",
  0x0451D7BD: "F3",
  0x7356E72B: "F4",
  0x6A5FB691: "F5",
  0x1D588607: "F6",
  0x0DE79B96: "F7",
  0x7AE0AB00: "F8",
  0x1A2722E5: "F9",
  0x6D201273: "F10",
  0x742943C9: "F11",
  0x032E735F: "F12",
  0x1D4AE6FC: "`",
  0x6A4DD66A: "1",
  0x734487D0: "2",
  0x0443B746: "3",
  0x14FCAAD7: "4",
  0x63FB9A41: "5",
  0x310A7126: "6",
  0x460D41B0: "7",
  0x5F04100A: "8",
  0x2803209C: "9",
  0x3667B53F: "0",
  0x416085A9: "-",
  0x5869D413: "=",
  0x2F6EE485: "Backspace",
  0x3FD1F914: "Tab",
  0x48D6C982: "Q",
  0x28114067: "W",
  0x5F1670F1: "E",
  0x461F214B: "R",
  0x311811DD: "T",
  0x2F7C847E: "Y",
  0x587BB4E8: "U",
  0x4172E552: "I",
  0x3675D5C4: "O",
  0x26CAC855: "P",
  0x51CDF8C3: "[",
  0x6750D6A0: "]",
  0x1057E636: "\\",
  0x095EB78C: "Caps Lock",
  0x7E59871A: "A",
  0x603D12B9: "S",
  0x173A222F: "D",
  0x0E337395: "F",
  0x79344303: "G",
  0x698B5E92: "H",
  0x1E8C6E04: "J",
  0x7E4BE7E1: "K",
  0x094CD777: "L",
  0x104586CD: ";",
  0x6742B65B: " ",
  0x792623F8: "Enter",
  0x0E21136E: "Shift",
  0x172842D4: "Z",
  0x602F7242: "X",
  0x70906FD3: "C",
  0x07975F45: "V",
  0x5566B422: "B",
  0x226184B4: "N",
  0x3B68D50E: "M",
  0x4C6FE598: ",",
  0x520B703B: ".",
  0x250C40AD: "/",
  0x3C051117: "Ctrl",
  0x4B022181: "Windows",
  0x5BBD3C10: "Alt",
  0x2CBA0C86: "Space",
  0x4C7D8563: "Menu",
  0x3B7AB5F5: "Print Screen",
  0x2273E44F: "Scroll Lock",
  0x5574D4D9: "Pause",
  0x4B10417A: "Insert",
  0x3C1771EC: "Home",
  0x251E2056: "Page Up",
  0x521910C0: "Delete",
  0x42A60D51: "End",
  0x35A13DC7: "Page Down",
  0x4BE599AC: "\u2191",
  0x3CE2A93A: "\u2190",
  0x25EBF880: "\u2193",
  0x52ECC816: "\u2192",
  0x4C885DB5: "Num Lock",
  0x3B8F6D23: "Num /",
  0x22863C99: "Num *",
  0x55810C0F: "Num -",
  0x453E119E: "Num 7",
  0x32392108: "Num 8",
  0x52FEA8ED: "Num 9",
  0x25F9987B: "Num 4",
  0x3CF0C9C1: "Num 5",
  0x4BF7F957: "Num 6",
  0x55936CF4: "Num +",
  0x22945C62: "Num 1",
  0x3B9D0DD8: "Num 2",
  0x4C9A3D4E: "Num 3",
  0x5C2520DF: "Num 0",
  0x2B221049: "Num .",
  0x02FE7993: ":",
  0x75F94905: " ",
  0x6CF018BF: "^",
  0x1BF72829: "R Shift",
  0x0593BD8A: "R Alt",
  0x72948D1C: "R Ctrl",
  0x6B9DDCA6: "Num Enter",
  0x495B0A82: "R  Shft",
  0x50525B38: "R  Alt",
  0x27556BAE: "R  Ctrl",
};
