
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:flutter/foundation.dart';

import '../../fileTypeUtils/effects/estIO.dart';
import '../../fileTypeUtils/utils/ByteDataWrapper.dart';
import '../../utils/utils.dart';
import '../Property.dart';
import '../hasUuid.dart';
import '../listNotifier.dart';
import '../undoable.dart';

class EstData with HasUuid, Undoable {
  final ValueListNotifier<EstRecordWrapper> records;
  List<String> typeNames = [];
  final onAnyChange = ChangeNotifier();

  EstData(this.records) {
    records.addListener(_onListChange);
  }

  Future<void> loadFromEstFile(String path) async {
    var est = EstFile.read(await ByteDataWrapper.fromFile(path));
    records.clear();
    records.addAll(est.records
        .map((type) => EstRecordWrapper(ValueListNotifier(
          type.map((record) => EstEntryWrapper(record)).toList()
        )))
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
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = EstData(records.takeSnapshot() as ValueListNotifier<EstRecordWrapper>);
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

  EstRecordWrapper(this.entries, [bool isEnabledB = true])
    : isEnabled = BoolProp(isEnabledB) {
    entries.addListener(_onListChange);
    isEnabled.addListener(onAnyChange.notifyListeners);
    _onListChange();
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
    var snapshot = EstRecordWrapper(entries.takeSnapshot() as ValueListNotifier<EstEntryWrapper>, isEnabled.value);
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

class EstEntryWrapper with HasUuid, Undoable {
  final EstTypeEntry entry;
  final BoolProp isEnabled;
  final onAnyChange = ChangeNotifier();

  EstEntryWrapper(this.entry, [bool isEnabledB = true])
    : isEnabled = BoolProp(isEnabledB) {
    isEnabled.addListener(onAnyChange.notifyListeners);
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
    return EstEntryWrapper(entry);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json["u_a"] = entry.header.u_a;
    json["id"] = entry.header.id;
    json["size"] = entry.header.size;
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
    var snapshot = EstEntryWrapper(entry, isEnabled.value);
    snapshot.overrideUuid(uuid);
    return snapshot;
  }
  
  @override
  void restoreWith(Undoable snapshot) {
    var entrySnapshot = snapshot as EstEntryWrapper;
    isEnabled.value = entrySnapshot.isEnabled.value;
  }
}
