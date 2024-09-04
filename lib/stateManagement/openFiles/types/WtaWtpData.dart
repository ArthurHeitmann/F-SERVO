
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/wta/wtaExtractor.dart';
import '../../../fileTypeUtils/wta/wtaReader.dart';
import '../../../utils/Disposable.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../events/statusInfo.dart';
import '../../hasUuid.dart';
import '../../listNotifier.dart';
import '../../openFiles/openFilesManager.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';

class WtaWtpOptionalInfo extends OptionalFileInfo {
  final String wtpPath;

  WtaWtpOptionalInfo({ required this.wtpPath });
}
class WtaWtpData extends OpenFileData {
  String? wtpPath;
  WtaWtpTextures? textures;
  final bool isWtb;

  WtaWtpData(super.name, super.path, { super.secondaryName, WtaWtpOptionalInfo? optionalInfo, this.isWtb = false }) :
    wtpPath = optionalInfo?.wtpPath,
    super(type: FileType.wta, icon: Icons.image) {
    canBeReloaded = false;
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    // find wtp
    var datDir = dirname(path);
    var dttDir = isWtb ? null : await findDttDirOfDat(datDir);
    if (wtpPath == null && !isWtb) {
      var wtaName = basenameWithoutExtension(path);
      var wtpName = "$wtaName.wtp";
      // wtpPath = join(dttDir, wtpName);
      if (dttDir != null)
        wtpPath = join(dttDir, wtpName);
      else {
        wtpPath = join(datDir, wtpName);
        if (!await File(wtpPath!).exists()) {
          showToast("Can't find corresponding WTP file for $wtaName.wta in ${dttDir ?? datDir}");
          throw Exception("Can't find corresponding WTP file for $wtaName");
        }
      }
    }
    if (!isWtb && wtpPath == null) {
      showToast("Can't find corresponding WTP file in ${dttDir ?? datDir}");
      throw Exception("Can't find corresponding WTP file in ${dttDir ?? datDir}");
    }

    String extractDir = join(dttDir ?? datDir, "${basename(path)}_extracted");
    await Directory(extractDir).create(recursive: true);

    textures?.dispose();
    textures = await WtaWtpTextures.fromWtaWtp(uuid, path, wtpPath, extractDir, isWtb);

    await super.load();
  }

  @override
  Future<void> save() async {
    if (loadingState.value != LoadingState.loaded)
      return;

    await textures!.save();

    await super.save();
  }

  void onPropChanged() {
    setHasUnsavedChanges(true);
  }

  @override
  void dispose() {
    super.dispose();
    textures?.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = WtaWtpData(name.value, path, optionalInfo: wtpPath != null ? WtaWtpOptionalInfo(wtpPath: wtpPath!) : null);
    snapshot.optionalInfo = optionalInfo;
    snapshot.textures = textures?.takeSnapshot() as WtaWtpTextures?;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as WtaWtpData;
    textures?.restoreWith(content.textures!);
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
  }
}

class WtaTextureEntry with HasUuid, Undoable implements Disposable {
  final OpenFileId file;
  final HexProp? id;
  final StringProp path;
  final BoolProp? isAlbedo;
  final HexProp? flag;

  WtaTextureEntry(this.file, this.id, this.path, { this.isAlbedo, this.flag }) {
    id?.addListener(_onPropChange);
    path.addListener(_onPropChange);
    isAlbedo?.addListener(_onPropChange);
    flag?.addListener(_onPropChange);
  }

  void _onPropChange() {
    (areasManager.fromId(file) as WtaWtpData).onPropChanged();
  }

  @override
  void dispose() {
    id?.dispose();
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
      id?.takeSnapshot() as HexProp?,
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
    id?.restoreWith(snap.id!);
    path.restoreWith(snap.path);
    isAlbedo?.restoreWith(snap.isAlbedo!);
    flag?.restoreWith(snap.flag!);
  }
}

class WtaWtpTextures with HasUuid, Undoable implements Disposable {
  final OpenFileId file;
  final String wtaPath;
  final String? wtpPath;
  final bool isWtb;
  final int wtaVersion;
  final ValueListNotifier<WtaTextureEntry> textures;
  final bool hasAnySimpleModeFlags;
  final bool useFlagsSimpleMode;

  WtaWtpTextures(this.file, this.wtaPath, this.wtpPath, this.isWtb, this.wtaVersion, this.textures, this.useFlagsSimpleMode, this.hasAnySimpleModeFlags) {
    textures.addListener(_onPropChange);
  }

  static Future<WtaWtpTextures> fromWtaWtp(OpenFileId file, String wtaPath, String? wtpPath, String extractDir, bool isWtb) async {
    var wta = await WtaFile.readFromFile(wtaPath);
    var wtpFile = await File(isWtb ? wtaPath : wtpPath!).open();
    var textures = ValueListNotifier<WtaTextureEntry>([], fileId: file);
    try {
      for (int i = 0; i < wta.textureOffsets.length; i++) {
        messageLog.add("Extracting texture ${i + 1}/${wta.textureOffsets.length}");
        // var texturePath = join(extractDir, "${i}_${wta.textureIdx[i].toRadixString(16).padLeft(8, "0")}.dds");
        var texturePath = getWtaTexturePath(wta, i, extractDir);
        await wtpFile.setPosition(wta.textureOffsets[i]);
        var textureBytes = await wtpFile.read(wta.textureSizes[i]);
        await File(texturePath).writeAsBytes(textureBytes);
        BoolProp? isAlbedo;
        HexProp? flag;
        if (wta.textureFlags[i] == WtaFile.albedoFlag || wta.textureFlags[i] == WtaFile.noAlbedoFlag)
          isAlbedo = BoolProp(wta.textureFlags[i] == WtaFile.albedoFlag, fileId: file);
        else
          flag = HexProp(wta.textureFlags[i], fileId: file);
        textures.add(WtaTextureEntry(
          file,
          wta.textureIdx != null
            ? HexProp(wta.textureIdx![i], fileId: file)
            : null,
          StringProp(texturePath, fileId: file),
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

    return WtaWtpTextures(file, wtaPath, wtpPath, isWtb, wta.header.version, textures, useFlagsSimpleMode, hashAnySimpleModeFlags);
  }

  Future<void> save() async {
    var wta = WtaFile(
      WtaFileHeader.empty(version: wtaVersion),
      List.filled(textures.length, -1),
      await Future.wait(textures.map((e) => File(e.path.value).length())),
      List.generate(textures.length, (index) => textures[index].getFlag()),
      wtaVersion > 0 ? [] : null
    );

    if (wta.textureIdx != null) {
      if (!textures.every((e) => e.id != null)) {
        showToast("Mismatch: WTA has texture indices, but some textures are missing indices!");
        throw Exception("Mismatch: WTA has texture indices, but some textures are missing indices!");
      }
      wta.textureIdx = List.generate(textures.length, (index) => textures[index].id!.value);
    }

    wta.updateHeader(isWtb: isWtb);

    // update offsets (4096 byte alignment)
    int offset = isWtb ? alignTo(wta.header.getFileEnd(), 32) : 0;
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

  @override
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
      wtaVersion,
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
