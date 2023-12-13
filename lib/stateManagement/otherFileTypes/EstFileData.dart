
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/foundation.dart';

import '../../fileTypeUtils/effects/estEntryTypes.dart';
import '../../fileTypeUtils/effects/estIO.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../utils/utils.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../listNotifier.dart';
import '../openFilesManager.dart';
import '../undoable.dart';

class EstData with HasUuid, Undoable {
  final ValueListNotifier<EstRecordWrapper> records;
  List<String> typeNames = [];
  final ValueNotifier<SelectedEffectItem?> selectedEntry = ValueNotifier(null);
  final onAnyChange = ChangeNotifier();
  final OpenFileId fileId;

  EstData(this.records, this.fileId) {
    records.addListener(_onListChange);
  }

  Future<void> loadFromEstFile(String path) async {
    var est = EstFile.read(await ByteDataWrapper.fromFile(path));
    records.clear();
    records.addAll(est.records
        .map((type) => EstRecordWrapper(
          ValueListNotifier(
            type.map((record) => EstEntryWrapper.fromEntry(record)).toList()
          ),
          fileId,
        ))
    );
    typeNames = est.typeNames;
  }

  Future<void> save(String savePath) async {
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
    await backupFile(savePath);
    await bytes.save(savePath);
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

  void dispose() {
    records.dispose();
    onAnyChange.dispose();
    selectedEntry.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = EstData(records.takeSnapshot() as ValueListNotifier<EstRecordWrapper>, fileId);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var estSnapshot = snapshot as EstData;
    records.restoreWith(estSnapshot.records);
  }
}

class EstRecordWrapper with HasUuid, Undoable {
  final ValueListNotifier<EstEntryWrapper> entries;
  final BoolProp isEnabled;
  final onAnyChange = ChangeNotifier();
  final OpenFileId fileId;

  EstRecordWrapper(this.entries, this.fileId, [bool isEnabledB = true])
    : isEnabled = BoolProp(isEnabledB) {
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

class EstEntryWrapper<T extends EstTypeEntry> with HasUuid, Undoable {
  final T entry;
  final BoolProp isEnabled;
  final onAnyChange = ChangeNotifier();

  EstEntryWrapper.unknown(this.entry, [bool isEnabledB = true])
    : isEnabled = BoolProp(isEnabledB) {
    isEnabled.addListener(onAnyChange.notifyListeners);
  }

  static EstEntryWrapper<T> fromEntry<T extends EstTypeEntry>(T entry, [bool isEnabledB = true]) {
    if (entry is EstTypePartEntry)
      return EstPartEntryWrapper(entry, isEnabledB) as EstEntryWrapper<T>;
    else if (entry is EstTypeMoveEntry)
      return EstMoveEntryWrapper(entry, isEnabledB) as EstEntryWrapper<T>;
    else if (entry is EstTypeEmifEntry)
      return EstEmifEntryWrapper(entry, isEnabledB) as EstEntryWrapper<T>;
    else if (entry is EstTypeTexEntry)
      return EstTexEntryWrapper(entry, isEnabledB) as EstEntryWrapper<T>;
    else if (entry is EstTypeFwkEntry)
      return EstFwkEntryWrapper(entry, isEnabledB) as EstEntryWrapper<T>;
    else
      return EstEntryWrapper.unknown(entry, isEnabledB);
  }

  static EstEntryWrapper fromJson(Map data) {
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
    return EstEntryWrapper.fromEntry(entry);
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

  void dispose() {
    isEnabled.dispose();
    onAnyChange.dispose();
  }
 
  @override
  Undoable takeSnapshot() {
    var snapshot = EstEntryWrapper.fromEntry(entry, isEnabled.value);
    snapshot.overrideUuid(uuid);
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

  SpecificEstEntryWrapper(T entry, [bool isEnabledB = true])
      : super.unknown(entry, isEnabledB);
  
  @override
  void dispose() {
    super.dispose();
    for (var prop in allProps) {
      prop.dispose();
    }
  }
}

class EstPartEntryWrapper extends SpecificEstEntryWrapper<EstTypePartEntry> {
  final unknown = NumberProp(0, true);
  final anchorBone = NumberProp(0, true);

  EstPartEntryWrapper(EstTypePartEntry entry, [bool isEnabledB = true])
      : super(entry, isEnabledB) {
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
  final offset = VectorProp([0, 0, 0]);
  final spawnBoxSize = VectorProp([0, 0, 0]);
  final moveSpeed = VectorProp([0, 0, 0]);
  final moveSmallSpeed = VectorProp([0, 0, 0]);
  final angle = FloatProp(0);
  final scaleX = FloatProp(0);
  final scaleY = FloatProp(0);
  final scaleZ = FloatProp(0);
  final rgb = VectorProp([0, 0, 0]);
  final alpha = FloatProp(0);
  final fadeInSpeed = FloatProp(0);
  final fadeOutSpeed = FloatProp(0);
  final effectSizeLimit1 = FloatProp(0);
  final effectSizeLimit2 = FloatProp(0);
  final effectSizeLimit3 = FloatProp(0);
  final effectSizeLimit4 = FloatProp(0);

  EstMoveEntryWrapper(EstTypeMoveEntry entry, [bool isEnabledB = true])
      : super(entry, isEnabledB) {
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
  final count = NumberProp(0, true);
  final playDelay = NumberProp(0, true);
  final showAtOnce = NumberProp(0, true);
  final size = NumberProp(0, true);

  EstEmifEntryWrapper(EstTypeEmifEntry entry, [bool isEnabledB = true])
      : super(entry, isEnabledB) {
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
  final speed = FloatProp(0);
  final textureFileId = NumberProp(0, true);
  final size = FloatProp(0);
  final textureFileIndex = NumberProp(0, true);
  final textureFileTextureIndex = NumberProp(0, true);
  final meshId = NumberProp(0, true);
  final videoFps = NumberProp(0, true);
  final isSingleFrame = NumberProp(0, true);

  EstTexEntryWrapper(EstTypeTexEntry entry, [bool isEnabledB = true])
      : super(entry, isEnabledB) {
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
  final importedEffectId = NumberProp(0, true);

  EstFwkEntryWrapper(EstTypeFwkEntry entry, [bool isEnabledB = true])
      : super(entry, isEnabledB) {
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