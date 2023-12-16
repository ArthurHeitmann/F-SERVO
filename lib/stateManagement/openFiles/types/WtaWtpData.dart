
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../otherFileTypes/wtaData.dart';
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

  WtaWtpData(String name, String path, { super.secondaryName, WtaWtpOptionalInfo? optionalInfo, this.isWtb = false }) :
        wtpPath = optionalInfo?.wtpPath,
        super(type: FileType.wta, name, path, icon: Icons.image);

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
          showToast("Can't find corresponding WTP file");
          throw Exception("Can't find corresponding WTP file");
        }
      }
    }
    if (!isWtb && wtpPath == null) {
      showToast("Can't find corresponding WTP file");
      throw Exception("Can't find corresponding WTP file in ${dttDir ?? datDir}");
    }

    String extractDir;
    if (dttDir != null)
      extractDir = join(dttDir, "textures");
    else
      extractDir = join(datDir, "nier2blender_extracted", basename(path));
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
