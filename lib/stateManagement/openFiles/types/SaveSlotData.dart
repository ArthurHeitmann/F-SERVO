
import 'package:flutter/material.dart';

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

class SaveSlotData extends OpenFileData {
  SlotDataDat? slotData;

  SaveSlotData(super.name, super.path, { super.secondaryName })
      : super(type: FileType.saveSlotData, icon: Icons.save) {
    canBeReloaded = false;
  }

  @override
  Future<void> load() async {
    if (loadingState.value != LoadingState.notLoaded)
      return;
    loadingState.value = LoadingState.loading;

    var bytes = await ByteDataWrapper.fromFile(path);
    slotData?.dispose();
    slotData = SlotDataDat.read(bytes, uuid);
    for (var prop in slotData!.allProps())
      prop.addListener(_onPropChanged);

    await super.load();
  }

  void _onPropChanged() {
    setHasUnsavedChanges(true);
  }

  @override
  Future<void> save() async {
    if (loadingState.value != LoadingState.loaded)
      return;

    var bytes = await ByteDataWrapper.fromFile(path);
    slotData!.write(bytes);
    await backupFile(path);
    await bytes.save(path);

    await super.save();
  }

  @override
  void dispose() {
    super.dispose();
    slotData?.dispose();
  }

  @override
  Undoable takeSnapshot() {
    var snapshot = SaveSlotData(name.value, path);
    snapshot.optionalInfo = optionalInfo;
    snapshot.slotData = slotData?.takeSnapshot() as SlotDataDat?;
    snapshot.setHasUnsavedChanges(hasUnsavedChanges.value);
    snapshot.loadingState.value = loadingState.value;
    snapshot.overrideUuid(uuid);
    return snapshot;
  }

  @override
  void restoreWith(Undoable snapshot) {
    var content = snapshot as SaveSlotData;
    if (content.slotData != null)
      slotData?.restoreWith(content.slotData!);
    name.value = content.name.value;
    setHasUnsavedChanges(content.hasUnsavedChanges.value);
  }
}

class SaveInventoryItem with HasUuid, Undoable {
  final NumberProp id;
  final BoolProp isActive;
  final NumberProp count;

  SaveInventoryItem(this.id, this.isActive, this.count);

  SaveInventoryItem.read(ByteDataWrapper bytes, OpenFileId file) :
    id = NumberProp(bytes.readInt32(), true, fileId: file),
    isActive = BoolProp(bytes.readInt32() == 0x00070000, fileId: file),
    count = NumberProp(bytes.readInt32(), true, fileId: file);

  void write(ByteDataWrapper bytes) {
    bytes.writeInt32(id.value.toInt());
    bytes.writeInt32(isActive.value ? 0x00070000 : -1);
    bytes.writeInt32(count.value.toInt());
  }

  @override
  Undoable takeSnapshot() {
    return SaveInventoryItem(
      id.takeSnapshot() as NumberProp,
      isActive.takeSnapshot() as BoolProp,
      count.takeSnapshot() as NumberProp
    );
  }

  @override
  void restoreWith(Undoable snapshot) {
    var item = snapshot as SaveInventoryItem;
    id.restoreWith(item.id);
    isActive.restoreWith(item.isActive);
    count.restoreWith(item.count);
  }
}

class SaveWeapon with HasUuid, Undoable {
  final int index;
  final NumberProp id;
  final NumberProp level;
  final BoolProp isNew;
  final BoolProp hasNewStory;
  final NumberProp enemiesDefeated;

  SaveWeapon(this.index, this.id, this.level, this.isNew, this.hasNewStory, this.enemiesDefeated);

  SaveWeapon.read(this.index, ByteDataWrapper bytes, OpenFileId file) :
    id = NumberProp(bytes.readInt32(), true, fileId: file),
    level = NumberProp(bytes.readInt32(), true, fileId: file),
    isNew = BoolProp(bytes.readInt32() == 1, fileId: file),
    hasNewStory = BoolProp(bytes.readInt32() == 1, fileId: file),
    enemiesDefeated = NumberProp(bytes.readInt32(), true, fileId: file);

  void write(ByteDataWrapper bytes) {
    bytes.writeInt32(id.value.toInt());
    bytes.writeInt32(level.value.toInt());
    bytes.writeInt32(isNew.value ? 1 : 0);
    bytes.writeInt32(hasNewStory.value ? 1 : 0);
    bytes.writeInt32(enemiesDefeated.value.toInt());
  }

  @override
  Undoable takeSnapshot() {
    return SaveWeapon(
      index,
      id.takeSnapshot() as NumberProp,
      level.takeSnapshot() as NumberProp,
      isNew.takeSnapshot() as BoolProp,
      hasNewStory.takeSnapshot() as BoolProp,
      enemiesDefeated.takeSnapshot() as NumberProp
    );
  }

  @override
  void restoreWith(Undoable snapshot) {
    var weapon = snapshot as SaveWeapon;
    id.restoreWith(weapon.id);
    level.restoreWith(weapon.level);
    isNew.restoreWith(weapon.isNew);
    hasNewStory.restoreWith(weapon.hasNewStory);
    enemiesDefeated.restoreWith(weapon.enemiesDefeated);
  }
}

class SaveWeaponSet with HasUuid, Undoable {
  final NumberProp weaponIdLightAttack;
  final NumberProp weaponIdHeavyAttack;

  SaveWeaponSet(this.weaponIdLightAttack, this.weaponIdHeavyAttack);

  SaveWeaponSet.read(ByteDataWrapper bytes, OpenFileId file) :
    weaponIdLightAttack = NumberProp(bytes.readInt32(), true, fileId: file),
    weaponIdHeavyAttack = NumberProp(bytes.readInt32(), true, fileId: file);

  void write(ByteDataWrapper bytes) {
    bytes.writeInt32(weaponIdLightAttack.value.toInt());
    bytes.writeInt32(weaponIdHeavyAttack.value.toInt());
  }

  @override
  Undoable takeSnapshot() {
    return SaveWeaponSet(
      weaponIdLightAttack.takeSnapshot() as NumberProp,
      weaponIdHeavyAttack.takeSnapshot() as NumberProp
    );
  }

  @override
  void restoreWith(Undoable snapshot) {
    var weaponSet = snapshot as SaveWeaponSet;
    weaponIdLightAttack.restoreWith(weaponSet.weaponIdLightAttack);
    weaponIdHeavyAttack.restoreWith(weaponSet.weaponIdHeavyAttack);
  }
}

class SaveVector with HasUuid, Undoable {
  late final VectorProp vec;
  late final double w;

  SaveVector(this.vec, this.w);

  SaveVector.read(ByteDataWrapper bytes, OpenFileId file) {
    vec = VectorProp([
      bytes.readFloat32(),
      bytes.readFloat32(),
      bytes.readFloat32(),
    ], fileId: file);
    w = bytes.readFloat32();
  }


  void write(ByteDataWrapper bytes) {
    bytes.writeFloat32(vec[0].value.toDouble());
    bytes.writeFloat32(vec[1].value.toDouble());
    bytes.writeFloat32(vec[2].value.toDouble());
    bytes.writeFloat32(w);
  }

  @override
  Undoable takeSnapshot() {
    return SaveVector(
      vec.takeSnapshot() as VectorProp,
      w
    );
  }

  @override
  void restoreWith(Undoable snapshot) {
    var vector = snapshot as SaveVector;
    vec.restoreWith(vector.vec);
  }
}

class TreeEntry extends ListNotifier<TreeEntry> {
  final StringProp text;
  final OpenFileId file;

  TreeEntry(this.text, super.children, this.file)
    :super(fileId: file) {
    text.addListener(() {
      areasManager.fromId(file)?.setHasUnsavedChanges(true);
    });
  }

  @override
  Undoable takeSnapshot() {
    return TreeEntry(
      text.takeSnapshot() as StringProp,
      map((e) => e.takeSnapshot() as TreeEntry).toList(),
      file
    );
  }

  @override
  void restoreWith(Undoable snapshot) {
    var entry = snapshot as TreeEntry;
    text.restoreWith(entry.text);
    updateOrReplaceWith(entry.toList(), (obj) => obj.takeSnapshot() as TreeEntry);
  }
}

List<TreeEntry> _parseTree(String text, OpenFileId file) {
  List<TreeEntry> rootEntries = [];

  List<String> lines = text.split("\n");

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if (i + 1 == lines.length && line.isEmpty)
      break;
    int indentationLevel = 0;
    while (line.startsWith(" ", indentationLevel))
      indentationLevel++;
    line = line.substring(indentationLevel);

    TreeEntry entry = TreeEntry(StringProp(line, fileId: file), [], file);

    if (indentationLevel == 0) {
      rootEntries.add(entry);
    } else {
      TreeEntry parent = rootEntries.last;
      for (int i = 1; i < indentationLevel; i++)
        parent = parent.last;

      parent.add(entry);
    }
  }

  return rootEntries;
}

String _stringifyTree(List<TreeEntry> tree) {
  String text = "";

  for (TreeEntry entry in tree)
    text += _stringifyTreeEntry(entry, 0);

  return text;
}
String _stringifyTreeEntry(TreeEntry entry, int indentationLevel) {
  String text = " " * indentationLevel;
  text += "${entry.text.value}\n";

  for (TreeEntry child in entry)
    text += _stringifyTreeEntry(child, indentationLevel + 1);

  return text;
}

void _sortTree(List<TreeEntry> tree) {
  var sceneStateRes = tree.where((entry) => entry.text.value.startsWith("SceneState")).toList();
  if (sceneStateRes.isNotEmpty)
    _sortSceneStateEntries(sceneStateRes.first);
  var questEntryRes = tree.where((entry) => entry.text.value.startsWith("Quest")).toList();
  if (questEntryRes.isNotEmpty)
    _sortQuestEntries(questEntryRes.first);
}
void _sortSceneStateEntries(TreeEntry sceneStateEntry) {
  sceneStateEntry.sort((s0, s1) {
    var s0Hash = crc32(s0.text.value);
    var s1Hash = crc32(s1.text.value);
    return s0Hash.compareTo(s1Hash);
  });
}
void _sortQuestEntries(TreeEntry questEntry) {
  questEntry.sort((q0, q1) {
    var q0Id = int.tryParse(q0.text.value.substring(1));
    var q1Id = int.tryParse(q1.text.value.substring(1));
    if (q0Id == null || q1Id == null)
      return 0;
    return q0Id.compareTo(q1Id);
  });
}

class SlotDataDat with HasUuid, Undoable implements Disposable {
  final OpenFileId fileId;
  late final NumberProp steamId64;
  late final StringProp name;
  late final NumberProp money;
  late final NumberProp experience;
  late final StringProp phase;
  late final StringProp transporterFlag;
  late final SaveVector position;
  late final SaveVector rotation;
  late final StringProp corpseName;
  late final StringProp corpseOnlineName;
  late final SaveVector corpsePosition;
  late final List<SaveInventoryItem> inventory;
  late final List<SaveInventoryItem> corpseInventory;
  late final List<SaveWeapon> weapons;
  late final List<SaveWeaponSet> weaponSets;
  late final List<TreeEntry> tree;

  SlotDataDat(this.fileId, this.steamId64, this.name, this.money, this.experience, this.phase, this.transporterFlag, this.position, this.rotation, this.corpseName, this.corpseOnlineName, this.corpsePosition, this.inventory, this.corpseInventory, this.weapons, this.weaponSets, this.tree);

  SlotDataDat.read(ByteDataWrapper bytes, this.fileId) {
    bytes.position = 4;
    steamId64 = NumberProp(bytes.readInt64(), true, fileId: fileId);
    bytes.position = 0x34;
    name = StringProp(bytes.readString(35, encoding: StringEncoding.utf16).trimNull(), fileId: fileId);
    bytes.position = 0x3056C;
    money = NumberProp(bytes.readInt32(), true, fileId: fileId);
    bytes.position = 0x3871C;
    experience = NumberProp(bytes.readInt32(), true, fileId: fileId);
    bytes.position = 0x395F4;
    phase = StringProp(bytes.readString(32).trimNull(), fileId: fileId);
    transporterFlag = StringProp(bytes.readString(32).trimNull(), fileId: fileId);
    bytes.position = 0x3963C;
    position = SaveVector.read(bytes, fileId);
    rotation = SaveVector.read(bytes, fileId);
    bytes.position = 0x3884C;
    corpseOnlineName = StringProp(bytes.readString(128).trimNull(), fileId: fileId);
    corpseName = StringProp(bytes.readString(22, encoding: StringEncoding.utf16).trimNull(), fileId: fileId);
    bytes.position = 0x388F8;
    corpsePosition = SaveVector.read(bytes, fileId);
    bytes.position = 0x30570;
    inventory = List.generate(256, (index) => SaveInventoryItem.read(bytes, fileId));
    corpseInventory = List.generate(256, (index) => SaveInventoryItem.read(bytes, fileId));
    weapons = List.generate(80, (index) => SaveWeapon.read(index, bytes, fileId));
    bytes.position = 0x386F4;
    weaponSets = List.generate(2, (index) => SaveWeaponSet.read(bytes, fileId));
    bytes.position = 0x7C;
    var treeText = bytes.readString(0x30000).trimNull();
    tree = _parseTree(treeText, fileId);
  }

  void write(ByteDataWrapper bytes) {
    bytes.position = 4;
    bytes.writeInt64(steamId64.value.toInt());
    bytes.position = 0x34;
    bytes.writeString(name.value.padRight(35, "\x00"), StringEncoding.utf16);
    bytes.position = 0x3056C;
    bytes.writeInt32(money.value.toInt());
    bytes.position = 0x3871C;
    bytes.writeInt32(experience.value.toInt());
    bytes.position = 0x395F4;
    bytes.writeString(phase.value.padRight(32, "\x00"));
    bytes.writeString(transporterFlag.value.padRight(32, "\x00"));
    bytes.position = 0x3963C;
    position.write(bytes);
    rotation.write(bytes);
    bytes.position = 0x3884C;
    bytes.writeString(corpseOnlineName.value.padRight(128, "\x00"));
    bytes.writeString(corpseName.value.padRight(22, "\x00"), StringEncoding.utf16);
    bytes.position = 0x388F8;
    corpsePosition.write(bytes);
    bytes.position = 0x30570;
    for (var item in inventory)
      item.write(bytes);
    for (var item in corpseInventory)
      item.write(bytes);
    for (var weapon in weapons)
      weapon.write(bytes);
    bytes.position = 0x386F4;
    for (var weaponSet in weaponSets)
      weaponSet.write(bytes);
    bytes.position = 0x7C;
    _sortTree(tree);
    bytes.writeString(_stringifyTree(tree).padRight(0x30000, "\x00"));
  }

  Iterable<ChangeNotifier> allProps() {
    return [
      steamId64, name, money, experience, phase, transporterFlag,
      position.vec, rotation.vec,
      corpseName, corpseOnlineName, corpsePosition.vec,
      ...inventory.expand((e) => [e.id, e.count, e.isActive]),
      ...corpseInventory.expand((e) => [e.id, e.count, e.isActive]),
      ...weapons.expand((e) => [e.id, e.level, e.isNew, e.hasNewStory, e.enemiesDefeated]),
      ...weaponSets.expand((e) => [e.weaponIdLightAttack, e.weaponIdHeavyAttack]),
      ...tree.map((e) => <ChangeNotifier>[e.text, e]).expand((e) => e),
    ];
  }

  @override
  void dispose() {
    for (var prop in allProps())
      prop.dispose();
  }

  @override
  Undoable takeSnapshot() {
    return SlotDataDat(
      fileId,
      steamId64.takeSnapshot() as NumberProp,
      name.takeSnapshot() as StringProp,
      money.takeSnapshot() as NumberProp,
      experience.takeSnapshot() as NumberProp,
      phase.takeSnapshot() as StringProp,
      transporterFlag.takeSnapshot() as StringProp,
      position.takeSnapshot() as SaveVector,
      rotation.takeSnapshot() as SaveVector,
      corpseName.takeSnapshot() as StringProp,
      corpseOnlineName.takeSnapshot() as StringProp,
      corpsePosition.takeSnapshot() as SaveVector,
      inventory.map((e) => e.takeSnapshot() as SaveInventoryItem).toList(),
      corpseInventory.map((e) => e.takeSnapshot() as SaveInventoryItem).toList(),
      weapons.map((e) => e.takeSnapshot() as SaveWeapon).toList(),
      weaponSets.map((e) => e.takeSnapshot() as SaveWeaponSet).toList(),
      tree.map((e) => e.takeSnapshot() as TreeEntry).toList(),
    );
  }

  @override
  void restoreWith(Undoable snapshot) {
    var slotData = snapshot as SlotDataDat;
    steamId64.restoreWith(slotData.steamId64);
    name.restoreWith(slotData.name);
    money.restoreWith(slotData.money);
    experience.restoreWith(slotData.experience);
    phase.restoreWith(slotData.phase);
    transporterFlag.restoreWith(slotData.transporterFlag);
    position.restoreWith(slotData.position);
    rotation.restoreWith(slotData.rotation);
    corpseName.restoreWith(slotData.corpseName);
    corpseOnlineName.restoreWith(slotData.corpseOnlineName);
    corpsePosition.restoreWith(slotData.corpsePosition);
    for (var i = 0; i < inventory.length; i++)
      inventory[i].restoreWith(slotData.inventory[i]);
    for (var i = 0; i < corpseInventory.length; i++)
      corpseInventory[i].restoreWith(slotData.corpseInventory[i]);
    for (var i = 0; i < weapons.length; i++)
      weapons[i].restoreWith(slotData.weapons[i]);
    for (var i = 0; i < weaponSets.length; i++)
      weaponSets[i].restoreWith(slotData.weaponSets[i]);
    for (var i = 0; i < tree.length; i++)
      tree[i].restoreWith(slotData.tree[i]);
  }
}
