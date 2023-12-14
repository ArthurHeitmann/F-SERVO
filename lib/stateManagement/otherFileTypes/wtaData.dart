
import 'dart:io';

import 'package:path/path.dart';

import '../../fileTypeUtils/wta/wtaReader.dart';
import '../../utils/utils.dart';
import '../Property.dart';
import '../events/statusInfo.dart';
import '../hasUuid.dart';
import '../listNotifier.dart';
import '../openFiles/openFileTypes.dart';
import '../openFiles/openFilesManager.dart';
import '../undoable.dart';

class WtaTextureEntry with HasUuid, Undoable {
  final OpenFileId file;
  final HexProp id;
  final StringProp path;
  final BoolProp? isAlbedo;
  final HexProp? flag;

  WtaTextureEntry(this.file, this.id, this.path, { this.isAlbedo, this.flag }) {
    id.addListener(_onPropChange);
    path.addListener(_onPropChange);
    isAlbedo?.addListener(_onPropChange);
    flag?.addListener(_onPropChange);
  }

  void _onPropChange() {
    (areasManager.fromId(file) as WtaWtpData).onPropChanged();
  }

  void dispose() {
    id.dispose();
    path.dispose();
    isAlbedo?.dispose();
    flag?.dispose();
  }

  int getFlag() => isAlbedo != null
    ? (isAlbedo!.value ? WtaFile.albedoFlag : WtaFile.noAlbedoFlag)
    : flag!.value;
  
  @override
  Undoable takeSnapshot() {
    var snap = WtaTextureEntry(
      file,
      id.takeSnapshot() as HexProp,
      path.takeSnapshot() as StringProp,
      isAlbedo: isAlbedo?.takeSnapshot() as BoolProp?,
      flag: flag?.takeSnapshot() as HexProp?,
    );
    snap.overrideUuid(uuid);
    return snap;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var snap = snapshot as WtaTextureEntry;
    id.restoreWith(snap.id);
    path.restoreWith(snap.path);
    isAlbedo?.restoreWith(snap.isAlbedo!);
    flag?.restoreWith(snap.flag!);
  }
}

class WtaWtpTextures with HasUuid, Undoable {
  final OpenFileId file;
  final String wtaPath;
  final String? wtpPath;
  final bool isWtb;
  final ValueListNotifier<WtaTextureEntry> textures;
  final bool hasAnySimpleModeFlags;
  final bool useFlagsSimpleMode;

  WtaWtpTextures(this.file, this.wtaPath, this.wtpPath, this.isWtb, this.textures, this.useFlagsSimpleMode, this.hasAnySimpleModeFlags) {
    textures.addListener(_onPropChange);
  }

  static Future<WtaWtpTextures> fromWtaWtp(OpenFileId file, String wtaPath, String? wtpPath, String extractDir, bool isWtb) async {
    var wta = await WtaFile.readFromFile(wtaPath);
    var wtpFile = await File(isWtb ? wtaPath : wtpPath!).open();
    var textures = ValueListNotifier<WtaTextureEntry>([]);
    try {
      for (int i = 0; i < wta.textureOffsets.length; i++) {
        messageLog.add("Extracting texture ${i + 1}/${wta.textureOffsets.length}");
        var texturePath = join(extractDir, "${i}_${wta.textureIdx[i].toRadixString(16).padLeft(8, "0")}.dds");
        await wtpFile.setPosition(wta.textureOffsets[i]);
        var textureBytes = await wtpFile.read(wta.textureSizes[i]);
        await File(texturePath).writeAsBytes(textureBytes);
        BoolProp? isAlbedo;
        HexProp? flag;
        if (wta.textureFlags[i] == WtaFile.albedoFlag || wta.textureFlags[i] == WtaFile.noAlbedoFlag)
          isAlbedo = BoolProp(wta.textureFlags[i] == WtaFile.albedoFlag);
        else
          flag = HexProp(wta.textureFlags[i]);
        textures.add(WtaTextureEntry(
          file,
          HexProp(wta.textureIdx[i]),
          StringProp(texturePath),
          isAlbedo: isAlbedo,
          flag: flag,
        ));
      }
    } finally {
      await wtpFile.close();
    }

    bool hashAnySimpleModeFlags = textures.any((e) => e.isAlbedo != null);
    bool useFlagsSimpleMode = textures.every((e) => e.isAlbedo != null);

    messageLog.add("Done extracting textures");

    return WtaWtpTextures(file, wtaPath, wtpPath, isWtb, textures, useFlagsSimpleMode, hashAnySimpleModeFlags);
  }

  Future<void> save() async {
    var wta = await WtaFile.readFromFile(wtaPath);

    wta.textureIdx = List.generate(textures.length, (index) => textures[index].id.value);
    wta.textureOffsets = List.filled(textures.length, -1);
    wta.textureFlags = List.generate(
      textures.length,
      (index) => textures[index].getFlag(),
    );

    // update sizes
    wta.textureSizes = await Future.wait(textures.map((e) async {
      return await File(e.path.value).length();
    }));

    // update texture infos
    wta.textureInfo = await Future.wait(textures.map((e) async {
      return await WtaFileTextureInfo.fromDds(e.path.value);
    }));

    wta.updateHeader();

    // update offsets (4096 byte alignment)
    int offset = isWtb ? alignTo(wta.header.offsetTextureInfo + wta.textureInfo.length * 20, 32) : 0;
    for (int i = 0; i < wta.textureOffsets.length; i++) {
      wta.textureOffsets[i] = offset;
      offset += wta.textureSizes[i];
      offset = (offset + 4095) & ~4095;
    }

    // write wta
    await backupFile(wtaPath);
    await wta.writeToFile(wtaPath);
    messageLog.add("Saved WTA");

    // write wtp
    var textureFilePath = isWtb ? wtaPath : wtpPath!;
    await backupFile(textureFilePath);
    var wtpFile = await File(textureFilePath).open(mode: isWtb ? FileMode.append : FileMode.write);
    try {
      for (int i = 0; i < wta.textureOffsets.length; i++) {
        await wtpFile.setPosition(wta.textureOffsets[i]);
        var texturePath = textures[i].path.value;
        var textureBytes = await File(texturePath).readAsBytes();
        await wtpFile.writeFrom(textureBytes);
      }
      var endPadding = await wtpFile.position() % 4096;
      await wtpFile.writeFrom(List.filled(endPadding, 0));
    } finally {
      await wtpFile.close();
    }
    messageLog.add("Saved WTP");
  }

  void _onPropChange() {
    (areasManager.fromId(file) as WtaWtpData).onPropChanged();
  }

  void dispose() {
    textures.dispose();
  }

  @override
  Undoable takeSnapshot() {
    return WtaWtpTextures(
      file,
      wtaPath,
      wtpPath,
      isWtb,
      textures.takeSnapshot() as ValueListNotifier<WtaTextureEntry>,
      useFlagsSimpleMode,
      hasAnySimpleModeFlags,
    );
  }

  @override
  void restoreWith(Undoable snapshot) {
    var snap = snapshot as WtaWtpTextures;
    textures.restoreWith(snap.textures);
  }
}
