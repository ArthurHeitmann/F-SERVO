

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
import '../../../fileSystem/FileSystem.dart';

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

    if (await FS.i.existsFile(path)) {
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
          if (!await FS.i.existsFile(wtpPath!)) {
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
      await FS.i.createDirectory(extractDir);

      textures?.dispose();
      textures = await WtaWtpTextures.fromWtaWtp(uuid, path, wtpPath, extractDir, isWtb);
    }
    else if (await FS.i.existsDirectory(path)) {
      textures?.dispose();
      textures = await WtaWtpTextures.fromExtractedFolder(uuid, path);
    }
    else {
      showToast("File not found: $path");
      return;
    }

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
  final NumberProp? id;
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
      id?.takeSnapshot() as NumberProp?,
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
  String? wtaPath;
  String? wtpPath;
  final ValueNotifier<List<String>?> wtpDatsPath = ValueNotifier(null);
  final bool isWtb;
  final int wtaVersion;
  final ValueListNotifier<WtaTextureEntry> textures;
  final bool hasAnySimpleModeFlags;
  final bool useFlagsSimpleMode;

  WtaWtpTextures(this.file, this.wtaPath, this.wtpPath, this.isWtb, this.wtaVersion, this.textures, this.useFlagsSimpleMode, this.hasAnySimpleModeFlags) {
    textures.addListener(_onPropChange);
    
    if (wtpPath != null) {
      List<String> reversePaths = [];
      reversePaths.add(wtpPath!);
      var remainingPath = dirname(wtpPath!);
      while (datExtensions.any((ext) => basename(remainingPath).endsWith(ext))) {
        reversePaths.add(remainingPath);
        remainingPath = dirname(remainingPath);
        if (basename(remainingPath) == datSubExtractDir)
          remainingPath = dirname(remainingPath);
      }
      wtpDatsPath.value = reversePaths.reversed.toList();
    }
  }

  static Future<WtaWtpTextures> fromWtaWtp(OpenFileId file, String wtaPath, String? wtpPath, String extractDir, bool isWtb) async {
    var wta = await WtaFile.readFromFile(wtaPath);
    var wtaVersion = wta.header.version;
    if (![0, 1].contains(wtaVersion))
      showToast("Unexpected WTA version: $wtaVersion (supported: 0, 1)");
    var wtpFile = await FS.i.open(isWtb ? wtaPath : wtpPath!);
    var textures = ValueListNotifier<WtaTextureEntry>([], fileId: file);
    try {
      for (int i = 0; i < wta.textureOffsets.length; i++) {
        messageLog.add("Extracting texture ${i + 1}/${wta.textureOffsets.length}");
        // var texturePath = join(extractDir, "${i}_${wta.textureIdx[i].toRadixString(16).padLeft(8, "0")}.dds");
        var texturePath = getWtaTexturePath(wta, i, extractDir);
        var texturePathOld = getWtaTexturePathOld(wta, i, extractDir);
        if (await FS.i.existsFile(texturePathOld))
          await FS.i.renameFile(texturePathOld, texturePath);
        if (!await FS.i.existsFile(texturePath)) {
          await wtpFile.setPosition(wta.textureOffsets[i]);
          var textureBytes = await wtpFile.read(wta.textureSizes[i]);
          await FS.i.write(texturePath, textureBytes);
        }
        BoolProp? isAlbedo;
        HexProp? flag;
        if (wta.textureFlags[i] == WtaFile.albedoFlag || wta.textureFlags[i] == WtaFile.noAlbedoFlag)
          isAlbedo = BoolProp(wta.textureFlags[i] == WtaFile.albedoFlag, fileId: file);
        else
          flag = HexProp(wta.textureFlags[i], fileId: file);
        textures.add(WtaTextureEntry(
          file,
          wta.textureIdx != null
            ? NumberProp(wta.textureIdx![i], true, fileId: file)
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

    return WtaWtpTextures(file, wtaPath, wtpPath, isWtb, wtaVersion, textures, useFlagsSimpleMode, hashAnySimpleModeFlags);
  }

  static Future<({List<WtaTextureEntry> textures, bool hasId})> _findTexturesInFolder(String folder, bool isWtb, {bool? hasId}) async {
    var fileNamePattern = RegExp(r"^(\d+_)?[0-9a-fA-F]+\.dds$");
    var hexCheckPattern = RegExp(r"[a-fA-F]+\d*\.dds$");
    var textureFiles = await FS.i.listFiles(folder)
      .where((e) => fileNamePattern.hasMatch(basename(e)))
      .toList();
    var hasIndex = textureFiles.any((e) => basename(e).startsWith("0_") || basename(e) == "0.dds");
    hasId ??= !hasIndex || textureFiles.any((e) => basename(e).contains("_"));
    var usesHex = textureFiles.any((e) => hexCheckPattern.hasMatch(basename(e)));
    var typePatterns = {
      // hasIndex, hasId
      (false, true): RegExp(r"^([0-9a-fA-F]+)\.dds$"),
      (true, false): RegExp(r"^(\d+)\.dds$"),
      (true, true): RegExp(r"^(\d+)_([0-9a-fA-F]+)\.dds$"),
    };
    var typePattern = typePatterns[(hasIndex, hasId)]!;
    List<(int?, WtaTextureEntry)> textures = [];
    for (var file in textureFiles) {
      var match = typePattern.firstMatch(basename(file));
      var index = hasIndex ? int.parse(match!.group(1)!) : null;
      var id = hasId ? int.parse(match!.group(hasId ? 2  :1)!, radix: usesHex ? 16 : 10) : null;
      textures.add((index, WtaTextureEntry(
        file,
        id != null ? NumberProp(id, true, fileId: file) : null,
        StringProp(file, fileId: file),
        flag: HexProp(0x20000020, fileId: file),
      )));
    }

    textures.sort((a, b) {
      if (a.$1 != null && b.$1 != null)
        return a.$1!.compareTo(b.$1!);
      return a.$2.file.compareTo(b.$2.file);
    });

    return (
      textures: textures.map((e) => e.$2).toList(),
      hasId: hasId,
    );
  }

  static Future<WtaWtpTextures> fromExtractedFolder(OpenFileId file, String folder) async {
    var filename = basename(folder).replaceAll("_extracted", "");
    var isWtb = filename.endsWith(".wtb");
    if (!isWtb && !filename.endsWith(".wta")) {
      showToast("Unexpected folder name: $filename");
      throw Exception("Unexpected folder name: $filename");
    }
    var (:textures, :hasId) = await _findTexturesInFolder(folder, isWtb);
    var valueList = ValueListNotifier<WtaTextureEntry>(textures, fileId: file);
    return WtaWtpTextures(
      file,
      null, null,
      isWtb,
      hasId ? 1 : 0,
      valueList,
      false,
      false,
    );
  }

  Future<void> patchFromFolder(String folder) async {
    var (textures: folderTextures, hasId: _) = await _findTexturesInFolder(folder, isWtb, hasId: true);
    int added = 0;
    int updated = 0;
    for (var folderTexture in folderTextures) {
      var currentTexture = textures.where((e) => e.id!.value == folderTexture.id!.value).firstOrNull;
      if (currentTexture != null) {
        currentTexture.path.value = folderTexture.path.value;
        folderTexture.dispose();
        updated++;
      }
      else {
        textures.add(folderTexture);
        added++;
      }
    }
    showToast("Added $added textures, updated $updated textures");
  }

  Future<void> save() async {
    if (wtaPath == null) {
      var result = await FS.i.selectSaveFile(
        allowedExtensions: [isWtb ? "wtb" : "wta"],
        dialogTitle: isWtb ? "Save WTB" : "Save WTA",
      );
      if (result == null)
        return;
      wtaPath = result;
    }
    if (wtpPath == null && !isWtb) {
      var result = await FS.i.selectSaveFile(
        allowedExtensions: ["wtp"],
        dialogTitle: "Save WTP",
        fileName: "${basenameWithoutExtension(wtaPath!)}.wtp",
      );
      if (result == null)
        return;
      wtpPath = result;
    }

    var wta = WtaFile(
      WtaFileHeader.empty(version: wtaVersion),
      List.filled(textures.length, -1),
      await Future.wait(textures.map((e) => FS.i.getSize(e.path.value))),
      List.generate(textures.length, (index) => textures[index].getFlag()),
      wtaVersion > 0 ? [] : null
    );

    if (wta.textureIdx != null) {
      if (!textures.every((e) => e.id != null)) {
        showToast("Mismatch: WTA has texture indices, but some textures are missing indices!");
        throw Exception("Mismatch: WTA has texture indices, but some textures are missing indices!");
      }
      wta.textureIdx = List.generate(textures.length, (index) => textures[index].id!.value.toInt());
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
    await backupFile(wtaPath!);
    await wta.writeToFile(wtaPath!);
    messageLog.add("Saved WTA");

    // write wtp
    var textureFilePath = isWtb ? wtaPath! : wtpPath!;
    await backupFile(textureFilePath);
    var wtpFile = await FS.i.open(textureFilePath, mode: isWtb ? FileMode.append : FileMode.write);
    try {
      for (int i = 0; i < wta.textureOffsets.length; i++) {
        await wtpFile.setPosition(wta.textureOffsets[i]);
        var texturePath = textures[i].path.value;
        var textureBytes = await FS.i.read(texturePath);
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
    wtpDatsPath.dispose();
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
