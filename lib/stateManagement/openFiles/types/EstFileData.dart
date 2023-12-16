// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../fileTypeUtils/effects/estEntryTypes.dart';
import '../../../fileTypeUtils/effects/estIO.dart';
import '../../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../../randomScripts/bnkWemAdder.dart';
import '../../../utils/Disposable.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
import '../../changesExporter.dart';
import '../../hasUuid.dart';
import '../../listNotifier.dart';
import '../../undoable.dart';
import '../openFileTypes.dart';
import '../openFilesManager.dart';

class EstFileData extends OpenFileData {
  late final ValueListNotifier<EstRecordWrapper> records;
  List<String> typeNames;
  final ValueNotifier<SelectedEffectItem?> selectedEntry = ValueNotifier(null);
  final onAnyChange = ChangeNotifier();

  EstFileData(super.name, super.path, { super.secondaryName, ValueListNotifier<EstRecordWrapper>? records, List<String>? typeNames }) :
    typeNames = List.unmodifiable(typeNames ?? []),
    super(type: FileType.est, icon: Icons.subtitles)
  {
    this.records = records ?? ValueListNotifier([], fileId: uuid);
    this.records.addListener(_onListChange);
    onAnyChange.addListener(_onAnyChange);
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var est = EstFile.read(await ByteDataWrapper.fromFile(path));
    for (var record in records)
      record.dispose();
    records.clear();
    records.addAll(est.records
      .map((type) => EstRecordWrapper(
        ValueListNotifier(
          type.map((record) => EstEntryWrapper.fromEntry(record, uuid)).toList(),
          fileId: uuid
        ),
        uuid,
      ))
    );
    typeNames = List.unmodifiable(est.typeNames);

    await super.load();
  }

  @override
  Future<void> save() async {
    var est = EstFile.fromRecords(
      records
          .where((record) => record.isEnabled.value)
          .map((record) => record.entries
          .where((entry) => entry.isEnabled.value)
          .map((entry) => entry.entry)
          .toList()
      )
          .toList(),
      typeNames,
    );
    var bytes = ByteDataWrapper.allocate(est.calculateStructSize());
    est.write(bytes);
    await backupFile(path);
    await bytes.save(path);

    var datDir = dirname(path);
    changedDatFiles.add(datDir);

    await super.save();
  }

  void _onAnyChange() {
    setHasUnsavedChanges(true);
    onUndoableEvent();
  }

  void removeRecord(EstRecordWrapper record) {
    if (
    selectedEntry.value?.record == record ||
        selectedEntry.value?.entry != null && record.entries.any((e) => e == selectedEntry.value?.entry)
    ) {
      selectedEntry.value = null;
    }
    records.remove(record);
  }

  void _onListChange() {
    for (var record in records) {
      record.onAnyChange.removeListener(onAnyChange.notifyListeners); // to avoid duplicate listeners
      record.onAnyChange.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.notifyListeners();
  }

  @override
  void dispose() {
    records.dispose();
    onAnyChange.dispose();
    selectedEntry.dispose();
    super.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = EstFileData(
      name.value,
      path,
      records: records.takeSnapshot() as ValueListNotifier<EstRecordWrapper>,
      typeNames: typeNames,
    );
    snapshot.optionalInfo = optionalInfo;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as EstFileData;
    name.value = content.name.value;
    records.restoreWith(content.records);
    typeNames = content.typeNames;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
  }
}


class EstRecordWrapper with HasUuid, Undoable implements Disposable {
  final ValueListNotifier<EstEntryWrapper> entries;
  final BoolProp isEnabled;
  final onAnyChange = ChangeNotifier();
  final OpenFileId fileId;

  EstRecordWrapper(this.entries, this.fileId, [bool isEnabledB = true])
      : isEnabled = BoolProp(isEnabledB, fileId: fileId) {
    entries.addListener(_onListChange);
    isEnabled.addListener(onAnyChange.notifyListeners);
    _onListChange();
  }

  void removeEntry(EstEntryWrapper entry) {
    entries.remove(entry);
  }

  void _onListChange() {
    for (var entry in entries) {
      entry.onAnyChange.removeListener(onAnyChange.notifyListeners); // to avoid duplicate listeners
      entry.onAnyChange.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.notifyListeners();
  }

  @override
  void dispose() {
    entries.dispose();
    isEnabled.dispose();
    onAnyChange.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = EstRecordWrapper(entries.takeSnapshot() as ValueListNotifier<EstEntryWrapper>, fileId, isEnabled.value);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var recordSnapshot = snapshot as EstRecordWrapper;
    isEnabled.value = recordSnapshot.isEnabled.value;
    entries.restoreWith(recordSnapshot.entries);
  }
}

class EstEntryWrapper<T extends EstTypeEntry> with HasUuid, Undoable implements Disposable {
  final OpenFileId fileId;
  final T entry;
  final BoolProp isEnabled;
  final onAnyChange = ChangeNotifier();

  EstEntryWrapper.unknown(this.entry, this.fileId, [bool isEnabledB = true])
      : isEnabled = BoolProp(isEnabledB, fileId: fileId) {
    isEnabled.addListener(onAnyChange.notifyListeners);
  }

  static EstEntryWrapper<T> fromEntry<T extends EstTypeEntry>(T entry, OpenFileId fileId, [bool isEnabledB = true]) {
    if (entry is EstTypePartEntry)
      return EstPartEntryWrapper(entry, fileId, isEnabledB) as EstEntryWrapper<T>;
    else if (entry is EstTypeMoveEntry)
      return EstMoveEntryWrapper(entry, fileId, isEnabledB) as EstEntryWrapper<T>;
    else if (entry is EstTypeEmifEntry)
      return EstEmifEntryWrapper(entry, fileId, isEnabledB) as EstEntryWrapper<T>;
    else if (entry is EstTypeTexEntry)
      return EstTexEntryWrapper(entry, fileId, isEnabledB) as EstEntryWrapper<T>;
    else if (entry is EstTypeFwkEntry)
      return EstFwkEntryWrapper(entry, fileId, isEnabledB) as EstEntryWrapper<T>;
    else
      return EstEntryWrapper.unknown(entry, fileId, isEnabledB);
  }

  static EstEntryWrapper fromJson(Map data, OpenFileId fileId) {
    var header = EstTypeHeader(
      data["u_a"],
      data["id"],
      data["size"],
      0,
    );
    String bytesStr = data["bytes"];
    var bytes = bytesStr
        .split(" ")
        .map((byteStr) => int.parse(byteStr, radix: 16))
        .toList();
    var byteBuffer = Uint8List.fromList(bytes).buffer;
    var entry = EstTypeEntry.read(ByteDataWrapper(byteBuffer), header);
    return EstEntryWrapper.fromEntry(entry, fileId);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      "u_a": entry.header.u_a,
      "id": entry.header.id,
      "size": entry.header.size,
    };
    var bytes = ByteDataWrapper.allocate(entry.header.size);
    entry.write(bytes);
    json["bytes"] = bytes
        .buffer.asUint8List()
        .map((byte) => byte.toRadixString(16).padLeft(2, "0"))
        .join(" ");
    return json;
  }

  @override
  void dispose() {
    isEnabled.dispose();
    onAnyChange.dispose();
  }

  @override
  Undoable takeSnapshot() {
    // var snapshot = EstEntryWrapper.fromEntry(entry, fileId, isEnabled.value);
    var snapshot = EstEntryWrapper.fromJson(toJson(), fileId);
    snapshot.overrideUuid(uuid);
    snapshot.isEnabled.value = isEnabled.value;
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entrySnapshot = snapshot as EstEntryWrapper;
    isEnabled.value = entrySnapshot.isEnabled.value;
    _readFromEntry(entrySnapshot.entry as T);
  }

  void _readFromEntry(T entry) {
  }
}

class SpecificEstEntryWrapper<T extends EstTypeEntry> extends EstEntryWrapper<T> {
  late final List<Prop> allProps;

  SpecificEstEntryWrapper(super.entry, super.fileId, [super.isEnabledB])
      : super.unknown();

  @override
  void dispose() {
    super.dispose();
    for (var prop in allProps) {
      prop.dispose();
    }
  }
}

class EstPartEntryWrapper extends SpecificEstEntryWrapper<EstTypePartEntry> {
  final NumberProp unknown;
  final NumberProp anchorBone;

  EstPartEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    unknown = NumberProp(0, true, fileId: fileId),
    anchorBone = NumberProp(0, true, fileId: fileId)
  {
    _readFromEntry(entry);
    allProps = [
      unknown,
      anchorBone,
    ];
    for (var prop in allProps) {
      prop.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.addListener(_updateEntryValues);
  }

  void _updateEntryValues() {
    entry.u_a = unknown.value.toInt();
    entry.anchor_bone = anchorBone.value.toInt();
  }

  @override
  void _readFromEntry(EstTypePartEntry entry) {
    unknown.value = entry.u_a;
    anchorBone.value = entry.anchor_bone;
  }
}

class EstMoveEntryWrapper extends SpecificEstEntryWrapper<EstTypeMoveEntry> {
  final VectorProp offset ;
  final VectorProp spawnBoxSize ;
  final VectorProp moveSpeed ;
  final VectorProp moveSmallSpeed ;
  final FloatProp angle ;
  final FloatProp scaleX ;
  final FloatProp scaleY ;
  final FloatProp scaleZ ;
  final VectorProp rgb ;
  final FloatProp alpha ;
  final FloatProp fadeInSpeed ;
  final FloatProp fadeOutSpeed ;
  final FloatProp effectSizeLimit1 ;
  final FloatProp effectSizeLimit2 ;
  final FloatProp effectSizeLimit3 ;
  final FloatProp effectSizeLimit4 ;

  EstMoveEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    offset = VectorProp([0, 0, 0], fileId: fileId),
    spawnBoxSize = VectorProp([0, 0, 0], fileId: fileId),
    moveSpeed = VectorProp([0, 0, 0], fileId: fileId),
    moveSmallSpeed = VectorProp([0, 0, 0], fileId: fileId),
    angle = FloatProp(0, fileId: fileId),
    scaleX = FloatProp(0, fileId: fileId),
    scaleY = FloatProp(0, fileId: fileId),
    scaleZ = FloatProp(0, fileId: fileId),
    rgb = VectorProp([0, 0, 0], fileId: fileId),
    alpha = FloatProp(0, fileId: fileId),
    fadeInSpeed = FloatProp(0, fileId: fileId),
    fadeOutSpeed = FloatProp(0, fileId: fileId),
    effectSizeLimit1 = FloatProp(0, fileId: fileId),
    effectSizeLimit2 = FloatProp(0, fileId: fileId),
    effectSizeLimit3 = FloatProp(0, fileId: fileId),
    effectSizeLimit4 = FloatProp(0, fileId: fileId)
  {
    _readFromEntry(entry);
    allProps = [
      offset,
      spawnBoxSize,
      moveSpeed,
      moveSmallSpeed,
      angle,
      scaleX,
      scaleY,
      scaleZ,
      rgb,
      alpha,
      fadeInSpeed,
      fadeOutSpeed,
      effectSizeLimit1,
      effectSizeLimit2,
      effectSizeLimit3,
      effectSizeLimit4,
    ];
    for (var prop in allProps) {
      prop.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.addListener(_updateEntryValues);
  }

  void _updateEntryValues() {
    entry.offset_x = offset[0].value.toDouble();
    entry.offset_y = offset[1].value.toDouble();
    entry.offset_z = offset[2].value.toDouble();
    entry.spawn_area_width = spawnBoxSize[0].value.toDouble();
    entry.spawn_area_height = spawnBoxSize[1].value.toDouble();
    entry.spawn_area_depth = spawnBoxSize[2].value.toDouble();
    entry.move_speed_x = moveSpeed[0].value.toDouble();
    entry.move_speed_y = moveSpeed[1].value.toDouble();
    entry.move_speed_z = moveSpeed[2].value.toDouble();
    entry.move_small_speed_x = moveSmallSpeed[0].value.toDouble();
    entry.move_small_speed_y = moveSmallSpeed[1].value.toDouble();
    entry.move_small_speed_z = moveSmallSpeed[2].value.toDouble();
    entry.angle = angle.value;
    entry.scale1 = scaleX.value;
    entry.scale2 = scaleY.value;
    entry.scale3 = scaleZ.value;
    entry.red = rgb[0].value.toDouble();
    entry.green = rgb[1].value.toDouble();
    entry.blue = rgb[2].value.toDouble();
    entry.alpha = alpha.value;
    entry.fadeInSpeed = fadeInSpeed.value.toDouble();
    entry.fadeOutSpeed = fadeOutSpeed.value;
    entry.effect_size_limit_1 = effectSizeLimit1.value;
    entry.effect_size_limit_2 = effectSizeLimit2.value;
    entry.effect_size_limit_3 = effectSizeLimit3.value;
    entry.effect_size_limit_4 = effectSizeLimit4.value;
  }

  @override
  void _readFromEntry(EstTypeMoveEntry entry) {
    offset[0].value = entry.offset_x;
    offset[1].value = entry.offset_y;
    offset[2].value = entry.offset_z;
    spawnBoxSize[0].value = entry.spawn_area_width;
    spawnBoxSize[1].value = entry.spawn_area_height;
    spawnBoxSize[2].value = entry.spawn_area_depth;
    moveSpeed[0].value = entry.move_speed_x;
    moveSpeed[1].value = entry.move_speed_y;
    moveSpeed[2].value = entry.move_speed_z;
    moveSmallSpeed[0].value = entry.move_small_speed_x;
    moveSmallSpeed[1].value = entry.move_small_speed_y;
    moveSmallSpeed[2].value = entry.move_small_speed_z;
    angle.value = entry.angle;
    scaleX.value = entry.scale1;
    scaleY.value = entry.scale2;
    scaleZ.value = entry.scale3;
    rgb[0].value = entry.red;
    rgb[1].value = entry.green;
    rgb[2].value = entry.blue;
    alpha.value = entry.alpha;
    fadeInSpeed.value = entry.fadeInSpeed;
    fadeOutSpeed.value = entry.fadeOutSpeed;
    effectSizeLimit1.value = entry.effect_size_limit_1;
    effectSizeLimit2.value = entry.effect_size_limit_2;
    effectSizeLimit3.value = entry.effect_size_limit_3;
    effectSizeLimit4.value = entry.effect_size_limit_4;
  }
}

class EstEmifEntryWrapper extends SpecificEstEntryWrapper<EstTypeEmifEntry> {
  final NumberProp count;
  final NumberProp playDelay;
  final NumberProp showAtOnce;
  final NumberProp size;

  EstEmifEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    count = NumberProp(0, true, fileId: fileId),
    playDelay = NumberProp(0, true, fileId: fileId),
    showAtOnce = NumberProp(0, true, fileId: fileId),
    size = NumberProp(0, true, fileId: fileId)
  {
    _readFromEntry(entry);
    allProps = [
      count,
      playDelay,
      showAtOnce,
      size,
    ];
    for (var prop in allProps) {
      prop.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.addListener(_updateEntryValues);
  }

  void _updateEntryValues() {
    entry.count = count.value.toInt();
    entry.play_delay = playDelay.value.toInt();
    entry.showAtOnce = showAtOnce.value.toInt();
    entry.size = size.value.toInt();
  }

  @override
  void _readFromEntry(EstTypeEmifEntry entry) {
    count.value = entry.count;
    playDelay.value = entry.play_delay;
    showAtOnce.value = entry.showAtOnce;
    size.value = entry.size;
  }
}

class EstTexEntryWrapper extends SpecificEstEntryWrapper<EstTypeTexEntry> {
  final FloatProp speed;
  final NumberProp textureFileId;
  final FloatProp size;
  final NumberProp textureFileIndex;
  final NumberProp textureFileTextureIndex;
  final NumberProp meshId;
  final NumberProp videoFps;
  final NumberProp isSingleFrame;

  EstTexEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    speed = FloatProp(0, fileId: fileId),
    textureFileId = NumberProp(0, true, fileId: fileId),
    size = FloatProp(0, fileId: fileId),
    textureFileIndex = NumberProp(0, true, fileId: fileId),
    textureFileTextureIndex = NumberProp(0, true, fileId: fileId),
    meshId = NumberProp(0, true, fileId: fileId),
    videoFps = NumberProp(0, true, fileId: fileId),
    isSingleFrame = NumberProp(0, true, fileId: fileId)
  {
    _readFromEntry(entry);
    allProps = [
      speed,
      textureFileId,
      size,
      textureFileIndex,
      textureFileTextureIndex,
      meshId,
      videoFps,
      isSingleFrame,
    ];
    for (var prop in allProps) {
      prop.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.addListener(_updateEntryValues);
  }

  void _updateEntryValues() {
    entry.speed = speed.value;
    entry.texture_file_id = textureFileId.value.toInt();
    entry.size = size.value;
    entry.texture_file_texture_index = textureFileIndex.value.toInt();
    entry.mesh_id = meshId.value.toInt();
    entry.video_fps_maybe = videoFps.value.toInt();
    entry.is_single_frame = isSingleFrame.value.toInt();
  }

  @override
  void _readFromEntry(EstTypeTexEntry entry) {
    speed.value = entry.speed;
    textureFileId.value = entry.texture_file_id;
    size.value = entry.size;
    textureFileIndex.value = entry.texture_file_texture_index;
    meshId.value = entry.mesh_id;
    videoFps.value = entry.video_fps_maybe;
    isSingleFrame.value = entry.is_single_frame;
  }
}

class EstFwkEntryWrapper extends SpecificEstEntryWrapper<EstTypeFwkEntry> {
  final NumberProp importedEffectId;

  EstFwkEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    importedEffectId = NumberProp(0, true, fileId: fileId)
  {
    _readFromEntry(entry);
    allProps = [
      importedEffectId,
    ];
    for (var prop in allProps) {
      prop.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.addListener(_updateEntryValues);
  }

  void _updateEntryValues() {
    entry.imported_effect_id = importedEffectId.value.toInt();
  }

  @override
  void _readFromEntry(EstTypeFwkEntry entry) {
    importedEffectId.value = entry.imported_effect_id;
  }
}

class SelectedEffectItem {
  final EstRecordWrapper? record;
  final EstEntryWrapper? entry;

  const SelectedEffectItem({this.record, this.entry});

  @override
  bool operator ==(Object other) {
    if (other is SelectedEffectItem) {
      return record == other.record && entry == other.entry;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(record, entry);
}
