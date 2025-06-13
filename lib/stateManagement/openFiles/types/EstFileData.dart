// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../fileTypeUtils/effects/estEntryTypes.dart';
import '../../../fileTypeUtils/effects/estIO.dart';
import '../../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../../utils/Disposable.dart';
import '../../../utils/utils.dart';
import '../../../widgets/filesView/FileType.dart';
import '../../Property.dart';
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
    else if (entry is EstTypeEmmvEntry)
      return EstEmmvEntryWrapper(entry, fileId, isEnabledB) as EstEntryWrapper<T>;
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
    var entry = EstTypeEntry.read(ByteDataWrapper.fromUint8List(Uint8List.fromList(bytes)), header);
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
    bytes.position = 0;
    json["bytes"] = bytes
        .asUint8List(bytes.length)
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
  final NumberProp anchorBone;
  final NumberProp u_a;
  final NumberProp u_b;
  final NumberProp u_c;
  final NumberProp u_d;
  final NumberProp u_e;
  final NumberProp u_1;
  final NumberProp u_2;
  final NumberProp u_3;
  final NumberProp u_4;
  final NumberProp u_5;
  final NumberProp u_6;
  final FloatProp u_7;
  final NumberProp u_8;

  EstPartEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    anchorBone = NumberProp(0, true, fileId: fileId),
    u_a = NumberProp(0, true, fileId: fileId),
    u_b = NumberProp(0, true, fileId: fileId),
    u_c = NumberProp(0, true, fileId: fileId),
    u_d = NumberProp(0, true, fileId: fileId),
    u_e = NumberProp(0, true, fileId: fileId),
    u_1 = NumberProp(0, true, fileId: fileId),
    u_2 = NumberProp(0, true, fileId: fileId),
    u_3 = NumberProp(0, true, fileId: fileId),
    u_4 = NumberProp(0, true, fileId: fileId),
    u_5 = NumberProp(0, true, fileId: fileId),
    u_6 = NumberProp(0, true, fileId: fileId),
    u_7 = FloatProp(0, fileId: fileId),
    u_8 = NumberProp(0, true, fileId: fileId)
  {
    _readFromEntry(entry);
    allProps = [
      anchorBone,
      u_a,
      u_b,
      u_c,
      u_d,
      u_e,
      u_1,
      u_2,
      u_3,
      u_4,
      u_5,
      u_6,
      u_7,
      u_8,
    ];
    for (var prop in allProps) {
      prop.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.addListener(_updateEntryValues);
  }

  void _updateEntryValues() {
    entry.anchor_bone = anchorBone.value.toInt();
    entry.u_a = u_a.value.toInt();
    entry.u_b = u_b.value.toInt();
    entry.u_c = u_c.value.toInt();
    entry.u_d = u_d.value.toInt();
    entry.some_kind_of_count = u_e.value.toInt();
    entry.u1 = u_1.value.toInt();
    entry.u2 = u_2.value.toInt();
    entry.u3 = u_3.value.toInt();
    entry.u4 = u_4.value.toInt();
    entry.u5 = u_5.value.toInt();
    entry.u6 = u_6.value.toInt();
    entry.u7 = u_7.value;
    entry.u8 = u_8.value.toInt();
  }

  @override
  void _readFromEntry(EstTypePartEntry entry) {
    anchorBone.value = entry.anchor_bone;
    u_a.value = entry.u_a;
    u_b.value = entry.u_b;
    u_c.value = entry.u_c;
    u_d.value = entry.u_d;
    u_e.value = entry.some_kind_of_count;
    u_1.value = entry.u1;
    u_2.value = entry.u2;
    u_3.value = entry.u3;
    u_4.value = entry.u4;
    u_5.value = entry.u5;
    u_6.value = entry.u6;
    u_7.value = entry.u7;
    u_8.value = entry.u8;
  }
}

class EstMoveEntryWrapper extends SpecificEstEntryWrapper<EstTypeMoveEntry> {
  final VectorProp offset;
  final VectorProp spawnBoxSize;
  final VectorProp moveSpeed;
  final VectorProp moveSmallSpeed;
  final FloatProp angle;
  final FloatProp scaleX;
  final FloatProp scaleY;
  final FloatProp scaleZ;
  final VectorProp rgb;
  final FloatProp alpha;
  final FloatProp fadeInSpeed;
  final FloatProp fadeOutSpeed;
  final FloatProp effectSizeLimit1;
  final FloatProp effectSizeLimit2;
  final FloatProp effectSizeLimit3;
  final FloatProp effectSizeLimit4;
  final NumberProp u_a;
  final List<FloatProp> u_b_1;
  final List<FloatProp> u_b_2;
  final List<FloatProp> u_c;
  final List<FloatProp> u_d_1;
  final List<FloatProp> u_d_2;

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
    effectSizeLimit4 = FloatProp(0, fileId: fileId),
    u_a = NumberProp(0, true, fileId: fileId),
    u_b_1 = List.generate(6, (_) => FloatProp(0, fileId: fileId)),
    u_b_2 = List.generate(12, (_) => FloatProp(0, fileId: fileId)),
    u_c = List.generate(15, (_) => FloatProp(0, fileId: fileId)),
    u_d_1 = List.generate(4, (_) => FloatProp(0, fileId: fileId)),
    u_d_2 = List.generate(32, (_) => FloatProp(0, fileId: fileId))
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
      u_a,
      ...u_b_1,
      ...u_b_2,
      ...u_c,
      ...u_d_1,
      ...u_d_2,
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
    entry.u_a = u_a.value.toInt();
    for (int i = 0; i < 6; i++)
      entry.u_b_1[i] = u_b_1[i].value;
    for (int i = 0; i < 12; i++)
      entry.u_b_2[i] = u_b_2[i].value;
    for (int i = 0; i < 15; i++)
      entry.u_c[i] = u_c[i].value;
    for (int i = 0; i < 4; i++)
      entry.u_d_1[i] = u_d_1[i].value;
    for (int i = 0; i < 32; i++)
      entry.u_d_2[i] = u_d_2[i].value;
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
    u_a.value = entry.u_a;
    for (int i = 0; i < 6; i++)
      u_b_1[i].value = entry.u_b_1[i];
    for (int i = 0; i < 12; i++)
      u_b_2[i].value = entry.u_b_2[i];
    for (int i = 0; i < 15; i++)
      u_c[i].value = entry.u_c[i];
    for (int i = 0; i < 4; i++)
      u_d_1[i].value = entry.u_d_1[i];
    for (int i = 0; i < 32; i++)
      u_d_2[i].value = entry.u_d_2[i];
  }
}

class EstEmifEntryWrapper extends SpecificEstEntryWrapper<EstTypeEmifEntry> {
  final NumberProp count;
  final NumberProp playDelay;
  final NumberProp showAtOnce;
  final NumberProp size;
  final NumberProp u_a;
  final NumberProp u_b;
  final NumberProp u_c;
  final NumberProp unk;
  final List<FloatProp> u_d;

  EstEmifEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    count = NumberProp(0, true, fileId: fileId),
    playDelay = NumberProp(0, true, fileId: fileId),
    showAtOnce = NumberProp(0, true, fileId: fileId),
    size = NumberProp(0, true, fileId: fileId),
    u_a = NumberProp(0, true, fileId: fileId),
    u_b = NumberProp(0, true, fileId: fileId),
    u_c = NumberProp(0, true, fileId: fileId),
    unk = NumberProp(0, true, fileId: fileId),
    u_d = List.generate(8, (_) => FloatProp(0, fileId: fileId))
  {
    _readFromEntry(entry);
    allProps = [
      count,
      playDelay,
      showAtOnce,
      size,
      u_a,
      u_b,
      u_c,
      unk,
      ...u_d,
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
    entry.u_a = u_a.value.toInt();
    entry.u_b = u_b.value.toInt();
    entry.u_c = u_c.value.toInt();
    entry.unk = unk.value.toInt();
    for (int i = 0; i < 8; i++)
      entry.u_d[i] = u_d[i].value;
  }

  @override
  void _readFromEntry(EstTypeEmifEntry entry) {
    count.value = entry.count;
    playDelay.value = entry.play_delay;
    showAtOnce.value = entry.showAtOnce;
    size.value = entry.size;
    u_a.value = entry.u_a;
    u_b.value = entry.u_b;
    u_c.value = entry.u_c;
    unk.value = entry.unk;
    for (int i = 0; i < 8; i++)
      u_d[i].value = entry.u_d[i];
  }
}

class EstTexEntryWrapper extends SpecificEstEntryWrapper<EstTypeTexEntry> {
  final FloatProp speed;
  final NumberProp textureFileId;
  final FloatProp size;
  final NumberProp textureFileIndex;
  final HexProp meshId;
  final NumberProp videoFps;
  final NumberProp isSingleFrame;
  final NumberProp u_c;
  final FloatProp u_d2;
  final FloatProp fadeOutStrength;
  final FloatProp u_d4;
  final FloatProp u_d5;
  final FloatProp u_g;
  final NumberProp u_h;
  final FloatProp distortion_effect_strength;
  final List<FloatProp> u_i2;
  final NumberProp u_i3;
  final List<FloatProp> u_i4;
  final FloatProp u_j;

  EstTexEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    speed = FloatProp(0, fileId: fileId),
    textureFileId = NumberProp(0, true, fileId: fileId),
    size = FloatProp(0, fileId: fileId),
    textureFileIndex = NumberProp(0, true, fileId: fileId),
    meshId = HexProp(0, fileId: fileId),
    videoFps = NumberProp(0, true, fileId: fileId),
    isSingleFrame = NumberProp(0, true, fileId: fileId),
    u_c = NumberProp(0, true, fileId: fileId),
    u_d2 = FloatProp(0, fileId: fileId),
    fadeOutStrength = FloatProp(0, fileId: fileId),
    u_d4 = FloatProp(0, fileId: fileId),
    u_d5 = FloatProp(0, fileId: fileId),
    u_g = FloatProp(0, fileId: fileId),
    u_h = NumberProp(0, true, fileId: fileId),
    distortion_effect_strength = FloatProp(0, fileId: fileId),
    u_i2 = List.generate(8, (_) => FloatProp(0, fileId: fileId)),
    u_i3 = NumberProp(0, true, fileId: fileId),
    u_i4 = List.generate(4, (_) => FloatProp(0, fileId: fileId)),
    u_j = FloatProp(0, fileId: fileId)
  {
    _readFromEntry(entry);
    allProps = [
      speed,
      textureFileId,
      size,
      textureFileIndex,
      meshId,
      videoFps,
      isSingleFrame,
      u_c,
      u_d2,
      fadeOutStrength,
      u_d4,
      u_d5,
      u_g,
      u_h,
      distortion_effect_strength,
      ...u_i2,
      u_i3,
      ...u_i4,
      u_j,
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
    entry.u_c = u_c.value.toInt();
    entry.u_d2 = u_d2.value;
    entry.fade_out_strength = fadeOutStrength.value;
    entry.u_d4 = u_d4.value;
    entry.u_d5 = u_d5.value;
    entry.u_g = u_g.value;
    entry.u_h = u_h.value.toInt();
    entry.distortion_effect_strength = distortion_effect_strength.value;
    for (int i = 0; i < 8; i++)
      entry.u_i2[i] = u_i2[i].value;
    entry.u_i3 = u_i3.value.toInt();
    for (int i = 0; i < 4; i++)
      entry.u_i4[i] = u_i4[i].value;
    entry.u_j = u_j.value;
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
    u_c.value = entry.u_c;
    u_d2.value = entry.u_d2;
    fadeOutStrength.value = entry.fade_out_strength;
    u_d4.value = entry.u_d4;
    u_d5.value = entry.u_d5;
    u_g.value = entry.u_g;
    u_h.value = entry.u_h;
    distortion_effect_strength.value = entry.distortion_effect_strength;
    for (int i = 0; i < 8; i++)
      u_i2[i].value = entry.u_i2[i];
    u_i3.value = entry.u_i3;
    for (int i = 0; i < 4; i++)
      u_i4[i].value = entry.u_i4[i];
    u_j.value = entry.u_j;
  }
}

class EstFwkEntryWrapper extends SpecificEstEntryWrapper<EstTypeFwkEntry> {
  final NumberProp importedEffectId;
  final NumberProp meshGroupIndex;
  final NumberProp u_a1;
  final List<NumberProp> u_b;
  final List<NumberProp> u_c;

  EstFwkEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    importedEffectId = NumberProp(0, true, fileId: fileId),
    meshGroupIndex = NumberProp(0, true, fileId: fileId),
    u_a1 = NumberProp(0, true, fileId: fileId),
    u_b = List.generate(3, (_) => NumberProp(0, true, fileId: fileId)),
    u_c = List.generate(5, (_) => NumberProp(0, true, fileId: fileId))
  {
    _readFromEntry(entry);
    allProps = [
      importedEffectId,
      meshGroupIndex,
      u_a1,
      ...u_b,
      ...u_c,
    ];
    for (var prop in allProps) {
      prop.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.addListener(_updateEntryValues);
  }

  void _updateEntryValues() {
    entry.imported_effect_id = importedEffectId.value.toInt();
    entry.mesh_group_index = meshGroupIndex.value.toInt();
    entry.u_a1 = u_a1.value.toInt();
    for (int i = 0; i < 3; i++)
      entry.u_b[i] = u_b[i].value.toInt();
    for (int i = 0; i < 5; i++)
      entry.u_c[i] = u_c[i].value.toInt();
  }

  @override
  void _readFromEntry(EstTypeFwkEntry entry) {
    importedEffectId.value = entry.imported_effect_id;
    meshGroupIndex.value = entry.mesh_group_index;
    u_a1.value = entry.u_a1;
    for (int i = 0; i < 3; i++)
      u_b[i].value = entry.u_b[i];
    for (int i = 0; i < 5; i++)
      u_c[i].value = entry.u_c[i];
  }
}

class EstEmmvEntryWrapper extends SpecificEstEntryWrapper<EstTypeEmmvEntry> {
  final NumberProp u_a;
  final FloatProp leftPos1;
  final FloatProp topPos;
  final FloatProp unkPos1;
  final FloatProp randomPos1;
  final FloatProp topBottomRandomPos1;
  final FloatProp frontBackRandomPos1;
  final FloatProp leftPos2;
  final FloatProp frontPos1;
  final FloatProp frontPos2;
  final FloatProp leftRightRandomPos1;
  final FloatProp randomPos2;
  final FloatProp frontBackRandomPos2;
  final FloatProp unkPos2;
  final FloatProp leftPosRandom1;
  final FloatProp topPos2;
  final FloatProp frontPos3;
  final FloatProp unkPos3;
  final FloatProp unkPos4;
  final FloatProp unkPos5;
  final FloatProp unkPos6;
  final FloatProp unkPos7;
  final FloatProp unkPos8;
  final FloatProp unkPos9;
  final FloatProp unkPos10;
  final FloatProp unkPos11;
  final FloatProp unkPos25;
  final FloatProp unkPos26;
  final FloatProp unkPos27;
  final FloatProp unkPos28;
  final FloatProp unkPos29;
  final FloatProp unkPos30;
  final FloatProp unkPos31;
  final FloatProp effectSize;
  final List<FloatProp> u_b_1;
  final FloatProp swordPos;
  final List<FloatProp> u_b_2;

  EstEmmvEntryWrapper(super.entry, super.fileId, [super.isEnabledB = true]) :
    u_a = NumberProp(0, true, fileId: fileId),
    leftPos1 = FloatProp(0, fileId: fileId),
    topPos = FloatProp(0, fileId: fileId),
    unkPos1 = FloatProp(0, fileId: fileId),
    randomPos1 = FloatProp(0, fileId: fileId),
    topBottomRandomPos1 = FloatProp(0, fileId: fileId),
    frontBackRandomPos1 = FloatProp(0, fileId: fileId),
    leftPos2 = FloatProp(0, fileId: fileId),
    frontPos1 = FloatProp(0, fileId: fileId),
    frontPos2 = FloatProp(0, fileId: fileId),
    leftRightRandomPos1 = FloatProp(0, fileId: fileId),
    randomPos2 = FloatProp(0, fileId: fileId),
    frontBackRandomPos2 = FloatProp(0, fileId: fileId),
    unkPos2 = FloatProp(0, fileId: fileId),
    leftPosRandom1 = FloatProp(0, fileId: fileId),
    topPos2 = FloatProp(0, fileId: fileId),
    frontPos3 = FloatProp(0, fileId: fileId),
    unkPos3 = FloatProp(0, fileId: fileId),
    unkPos4 = FloatProp(0, fileId: fileId),
    unkPos5 = FloatProp(0, fileId: fileId),
    unkPos6 = FloatProp(0, fileId: fileId),
    unkPos7 = FloatProp(0, fileId: fileId),
    unkPos8 = FloatProp(0, fileId: fileId),
    unkPos9 = FloatProp(0, fileId: fileId),
    unkPos10 = FloatProp(0, fileId: fileId),
    unkPos11 = FloatProp(0, fileId: fileId),
    unkPos25 = FloatProp(0, fileId: fileId),
    unkPos26 = FloatProp(0, fileId: fileId),
    unkPos27 = FloatProp(0, fileId: fileId),
    unkPos28 = FloatProp(0, fileId: fileId),
    unkPos29 = FloatProp(0, fileId: fileId),
    unkPos30 = FloatProp(0, fileId: fileId),
    unkPos31 = FloatProp(0, fileId: fileId),
    effectSize = FloatProp(0, fileId: fileId),
    u_b_1 = List.generate(6, (_) => FloatProp(0, fileId: fileId)),
    swordPos = FloatProp(0, fileId: fileId),
    u_b_2 = List.generate(12, (_) => FloatProp(0, fileId: fileId))
  {
    _readFromEntry(entry);
    allProps = [
      u_a,
      leftPos1,
      topPos,
      unkPos1,
      randomPos1,
      topBottomRandomPos1,
      frontBackRandomPos1,
      leftPos2,
      frontPos1,
      frontPos2,
      leftRightRandomPos1,
      randomPos2,
      frontBackRandomPos2,
      unkPos2,
      leftPosRandom1,
      topPos2,
      frontPos3,
      unkPos3,
      unkPos4,
      unkPos5,
      unkPos6,
      unkPos7,
      unkPos8,
      unkPos9,
      unkPos10,
      unkPos11,
      unkPos25,
      unkPos26,
      unkPos27,
      unkPos28,
      unkPos29,
      unkPos30,
      unkPos31,
      effectSize,
      ...u_b_1,
      swordPos,
      ...u_b_2,
    ];
    for (var prop in allProps) {
      prop.addListener(onAnyChange.notifyListeners);
    }
    onAnyChange.addListener(_updateEntryValues);
  }

  void _updateEntryValues() {
    entry.u_a = u_a.value.toInt();
    entry.left_pos1 = leftPos1.value;
    entry.top_pos = topPos.value;
    entry.unk_pos1 = unkPos1.value;
    entry.random_pos1 = randomPos1.value;
    entry.top_bottom_random_pos1 = topBottomRandomPos1.value;
    entry.front_back_random_pos1 = frontBackRandomPos1.value;
    entry.left_pos2 = leftPos2.value;
    entry.front_pos1 = frontPos1.value;
    entry.front_pos2 = frontPos2.value;
    entry.left_right_random_pos1 = leftRightRandomPos1.value;
    entry.random_pos2 = randomPos2.value;
    entry.front_back_random_pos2 = frontBackRandomPos2.value;
    entry.unk_pos2 = unkPos2.value;
    entry.left_pos_random1 = leftPosRandom1.value;
    entry.top_pos2 = topPos2.value;
    entry.front_pos3 = frontPos3.value;
    entry.unk_pos3 = unkPos3.value;
    entry.unk_pos4 = unkPos4.value;
    entry.unk_pos5 = unkPos5.value;
    entry.unk_pos6 = unkPos6.value;
    entry.unk_pos7 = unkPos7.value;
    entry.unk_pos8 = unkPos8.value;
    entry.unk_pos9 = unkPos9.value;
    entry.unk_pos10 = unkPos10.value;
    entry.unk_pos11 = unkPos11.value;
    entry.unk_pos25 = unkPos25.value;
    entry.unk_pos26 = unkPos26.value;
    entry.unk_pos27 = unkPos27.value;
    entry.unk_pos28 = unkPos28.value;
    entry.unk_pos29 = unkPos29.value;
    entry.unk_pos30 = unkPos30.value;
    entry.unk_pos31 = unkPos31.value;
    entry.effect_size = effectSize.value;
    for (int i = 0; i < 6; i++)
      entry.u_b_1[i] = u_b_1[i].value;
    entry.sword_pos = swordPos.value;
    for (int i = 0; i < 12; i++)
      entry.u_b_2[i] = u_b_2[i].value;
  }

  @override
  void _readFromEntry(EstTypeEmmvEntry entry) {
    u_a.value = entry.u_a;
    leftPos1.value = entry.left_pos1;
    topPos.value = entry.top_pos;
    unkPos1.value = entry.unk_pos1;
    randomPos1.value = entry.random_pos1;
    topBottomRandomPos1.value = entry.top_bottom_random_pos1;
    frontBackRandomPos1.value = entry.front_back_random_pos1;
    leftPos2.value = entry.left_pos2;
    frontPos1.value = entry.front_pos1;
    frontPos2.value = entry.front_pos2;
    leftRightRandomPos1.value = entry.left_right_random_pos1;
    randomPos2.value = entry.random_pos2;
    frontBackRandomPos2.value = entry.front_back_random_pos2;
    unkPos2.value = entry.unk_pos2;
    leftPosRandom1.value = entry.left_pos_random1;
    topPos2.value = entry.top_pos2;
    frontPos3.value = entry.front_pos3;
    unkPos3.value = entry.unk_pos3;
    unkPos4.value = entry.unk_pos4;
    unkPos5.value = entry.unk_pos5;
    unkPos6.value = entry.unk_pos6;
    unkPos7.value = entry.unk_pos7;
    unkPos8.value = entry.unk_pos8;
    unkPos9.value = entry.unk_pos9;
    unkPos10.value = entry.unk_pos10;
    unkPos11.value = entry.unk_pos11;
    unkPos25.value = entry.unk_pos25;
    unkPos26.value = entry.unk_pos26;
    unkPos27.value = entry.unk_pos27;
    unkPos28.value = entry.unk_pos28;
    unkPos29.value = entry.unk_pos29;
    unkPos30.value = entry.unk_pos30;
    unkPos31.value = entry.unk_pos31;
    effectSize.value = entry.effect_size;
    for (int i = 0; i < 6; i++)
      u_b_1[i].value = entry.u_b_1[i];
    swordPos.value = entry.sword_pos;
    for (int i = 0; i < 12; i++)
      u_b_2[i].value = entry.u_b_2[i];
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
