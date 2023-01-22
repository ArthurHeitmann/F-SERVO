
// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

import '../../../background/IdLookup.dart';
import '../../../stateManagement/Property.dart';
import '../../../stateManagement/nestedNotifier.dart';
import '../../../stateManagement/openFileTypes.dart';
import '../../../stateManagement/otherFileTypes/SlotDataDat.dart';
import '../../../stateManagement/otherFileTypes/itemIdsToNames.dart';
import '../../theme/customTheme.dart';
import '../simpleProps/UnderlinePropTextField.dart';
import '../simpleProps/propEditorFactory.dart';
import '../simpleProps/propTextField.dart';
import '../simpleProps/textFieldAutocomplete.dart';
import 'genericTable/tableEditor.dart';

class SaveSlotDataEditor extends StatefulWidget {
  final SaveSlotData save;

  const SaveSlotDataEditor({ super.key, required this.save });

  @override
  State<SaveSlotDataEditor> createState() => _SaveSlotDataEditorState();
}

class _SaveSlotDataEditorState extends State<SaveSlotDataEditor> {
  int activeTab = 0;

  @override
  void initState() {
    widget.save.load().then((_) => setState(() {}));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.save.loadingState != LoadingState.loaded) {
      return Column(
        children: const [
          SizedBox(height: 35),
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(backgroundColor: Colors.transparent,)
          )
        ],
      );
    }

    var save = widget.save.slotData!;
    return Column(
      children: [
        const SizedBox(height: 35),
        Row(
          children: [
            _makeTabButton(0, "General"),
            _makeTabButton(1, "Inventory"),
            _makeTabButton(2, "Corpse Inventory"),
            _makeTabButton(3, "Weapons"),
            _makeTabButton(4, "Scene State"),
          ]
        ),
        const Divider(height: 1,),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: IndexedStack(
              index: activeTab,
              children: [
                _GeneralEditor(save: save),
                _InventoryEditor(name: "Inventory", items: save.inventory),
                _InventoryEditor(
                  name: "Corpse Inventory",
                  items: save.corpseInventory,
                  additionalProps: [
                    _PropWithName(name: "Name", prop: save.corpseName),
                    _PropWithName(name: "Online Name", prop: save.corpseOnlineName),
                    _PropWithName(name: "Position", prop: save.corpsePosition.vec),
                  ],
                ),
                _WeaponEditor(save: save),
                _TogglesEditor(name: "Scene State", toggles: save.tree.where((e) => e.text.value == "SceneState").first),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _makeTabButton(int index, String text) {
    return Flexible(
      child: SizedBox(
        width: 200,
        height: 40,
        child: TextButton(
            onPressed: () {
              if (activeTab == index)
                return;
              setState(() => activeTab = index);
            },
            style: ButtonStyle(
              backgroundColor: activeTab == index
                ? MaterialStateProperty.all(getTheme(context).textColor!.withOpacity(0.1))
                : MaterialStateProperty.all(Colors.transparent),
              foregroundColor: activeTab == index
                ? MaterialStateProperty.all(getTheme(context).textColor)
                : MaterialStateProperty.all(getTheme(context).textColor!.withOpacity(0.5)),
            ),
            child: Text(
              text,
              textScaleFactor: 1.25,
            ),
          ),
      ),
    );
  }
}

class _PropWithName extends StatelessWidget {
  final String name;
  final Prop prop;
  final PropTFOptions options;

  const _PropWithName({ super.key, required this.name, required this.prop, this.options = const PropTFOptions() });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$name  "),
          Flexible(child: makePropEditor<UnderlinePropTextField>(prop, options)),
        ],
      ),
    );
  }
}

class _GeneralEditor extends StatelessWidget {
  final SlotDataDat save;

  const _GeneralEditor({ super.key, required this.save });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Container(
        decoration: BoxDecoration(
          color: getTheme(context).tableBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: getTheme(context).textColor!.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PropWithName(name: "Steam ID 64", prop: save.steamId64),
            _PropWithName(name: "Name", prop: save.name),
            _PropWithName(name: "Money", prop: save.money),
            _PropWithName(name: "Experience", prop: save.experience),
            _PropWithName(name: "Phase", prop: save.phase),
            _PropWithName(name: "Transporter", prop: save.transporterFlag),
            _PropWithName(name: "Position", prop: save.position.vec),
            _PropWithName(name: "Rotation", prop: save.rotation.vec),
          ]
        ),
      ),
    );
  }
}

class _InventoryTableConfig with CustomTableConfig {
  final List<SaveInventoryItem> items;

  _InventoryTableConfig(String name, this.items) {
    this.name = name;
    columnNames = ["i", "ID", "Count", "Is Active?"];
    columnFlex = [1, 2, 2, 1];
    rowCount = NumberProp(items.length, true)
      ..changesUndoable = false;
    allowRowAddRemove = false;
  }

  @override
  RowConfig rowPropsGenerator(int i) => RowConfig(
    key: Key(items[i].uuid),
    cells: [
      TextCellConfig(i.toString()),
      PropCellConfig(prop: items[i].id, autocompleteOptions: _getItemIdAutocomplete),
      PropCellConfig(prop: items[i].count),
      PropCellConfig(prop: items[i].isActive),
    ]
  );

  @override
  void updateRowWith(int index, List<String?> values) {
    items[index].id.updateWith(values[0]!);
    items[index].count.updateWith(values[1]!);
    items[index].isActive.updateWith(values[2]!);
  }

  @override
  void onRowAdd() { }

  @override
  void onRowRemove(int index) { }
}

class _InventoryEditor extends StatefulWidget {
  final List<SaveInventoryItem> items;
  final String name;
  final List<_PropWithName> additionalProps;

  const _InventoryEditor({ super.key, required this.items, required this.name, this.additionalProps = const [] });

  @override
  State<_InventoryEditor> createState() => __InventoryEditorState();
}

class __InventoryEditorState extends State<_InventoryEditor> {
  late _InventoryTableConfig tableConfig;

  @override
  void initState() {
    tableConfig = _InventoryTableConfig(widget.name, widget.items);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.additionalProps.isEmpty)
      return TableEditor(config: tableConfig);
    
    return Row(
      children: [
        Expanded(child: TableEditor(config: tableConfig)),
        const SizedBox(width: 16),
        Container(
          width: 300,
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.additionalProps,
          ),
        ),
      ],
    );
  }
}

class _WeaponTableConfig with CustomTableConfig {
  final List<SaveWeapon> weapons;

  _WeaponTableConfig(this.weapons) {
    name = "Weapons";
    columnNames = ["Index", "ID", "Level", "Is New?", "Has New Story?", "Kills" ];
    columnFlex = [4, 3, 3, 2, 2, 2];
    rowCount = NumberProp(weapons.length, true)
      ..changesUndoable = false;
    allowRowAddRemove = false;
  }

  @override
  RowConfig rowPropsGenerator(int i) => RowConfig(
    key: Key(weapons[i].uuid),
    cells: [
      TextCellConfig(weapons[i].index.toString().padLeft(2, " ") + (i < _weaponsByIndex.length ? " (${_weaponsByIndex[i].item2})" : "")),
      PropCellConfig(prop: weapons[i].id, autocompleteOptions: _getWeaponIdAutocomplete),
      PropCellConfig(prop: weapons[i].level),
      PropCellConfig(prop: weapons[i].isNew),
      PropCellConfig(prop: weapons[i].hasNewStory),
      PropCellConfig(prop: weapons[i].enemiesDefeated),
    ]
  );

  @override
  void updateRowWith(int index, List<String?> values) {
    // weapons[index].i.updateWith(values[0]!);
    weapons[index].id.updateWith(values[1]!);
    weapons[index].level.updateWith(values[2]!);
    weapons[index].isNew.updateWith(values[3]!);
    weapons[index].hasNewStory.updateWith(values[4]!);
    weapons[index].enemiesDefeated.updateWith(values[5]!);
  }

  @override
  void onRowAdd() { }

  @override
  void onRowRemove(int index) { }
}

class _WeaponEditor extends StatefulWidget {
  final SlotDataDat save;

  const _WeaponEditor({ super.key, required this.save });

  @override
  State<_WeaponEditor> createState() => __WeaponEditorState();
}

class __WeaponEditorState extends State<_WeaponEditor> {
  late _WeaponTableConfig tableConfig;

  @override
  void initState() {
    tableConfig = _WeaponTableConfig(widget.save.weapons);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var autocompleteOptions = const PropTFOptions(autocompleteOptions: _getWeaponIdAutocomplete);
    return Row(
      children: [
        Expanded(child: TableEditor(config: tableConfig)),
        const SizedBox(width: 16),
        Container(
          width: 125,
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Weapon Set 1", style: TextStyle(fontWeight: FontWeight.bold), textScaleFactor: 1.1),
              _PropWithName(name: "Light", prop: widget.save.weaponSets[0].weaponIdLightAttack, options: autocompleteOptions),
              _PropWithName(name: "Heavy", prop: widget.save.weaponSets[0].weaponIdHeavyAttack, options: autocompleteOptions),
              const SizedBox(height: 16),
              const Text("Weapon Set 2", style: TextStyle(fontWeight: FontWeight.bold), textScaleFactor: 1.1),
              _PropWithName(name: "Light", prop: widget.save.weaponSets[1].weaponIdLightAttack, options: autocompleteOptions),
              _PropWithName(name: "Heavy", prop: widget.save.weaponSets[1].weaponIdHeavyAttack, options: autocompleteOptions),
            ],
          ),
        ),
      ],
    );
  }
}

Iterable<AutocompleteConfig> _getWeaponIdAutocomplete() {
  return [
    const Tuple2<int, String>(-1, "Not owned"),
    ..._weaponsByIndex
  ].map((t) => AutocompleteConfig(
    "${t.item1} (${t.item2})",
    insertText: t.item1.toString(),
  ));
}

Iterable<AutocompleteConfig> _getItemIdAutocomplete() {
  return {
    -1: "Not owned",
    ...itemIdsToNames
  }.entries.map((t) => AutocompleteConfig(
    "${t.key} (${t.value})",
    insertText: t.key.toString(),
  ));
}

class _StringListTableConfig with CustomTableConfig {
  final NestedNotifier<TreeEntry> strings;
  final FutureOr<Iterable<AutocompleteConfig>> Function()? autocompleteOptions;

  _StringListTableConfig(String name, this.strings, [this.autocompleteOptions]) {
    this.name = name;
    columnNames = [name, ""];
    columnFlex = [5, 1];
    rowCount = NumberProp(strings.length, true);
    strings.addListener(_updateRowCount);
  }

  void _updateRowCount() {
    rowCount.value = strings.length;
  }

  @override
  RowConfig rowPropsGenerator(int index) {
    return RowConfig(
      key: Key(strings[index].uuid),
      cells: [
        PropCellConfig(
          prop: strings[index].text,
          autocompleteOptions: autocompleteOptions,
        ),
        CustomWidgetCellConfig(
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => strings.removeAt(index),
          ),
        ),
      ]
    );
  }
  
  @override
  void onRowAdd() {
    strings.add(TreeEntry(StringProp("new $name entry"), [], strings.first.file));
  }

  @override
  void onRowRemove(int index) {
    strings.removeAt(index);
  }

  @override
  void updateRowWith(int index, List<String?> values) {
    strings[index].text.updateWith(values[0]!);
  }

  @override
  void disposeConfig() {
    strings.removeListener(_updateRowCount);
    super.disposeConfig();
  }
}

class _TogglesEditor extends StatefulWidget {
  final String name;
  final NestedNotifier<TreeEntry> toggles;

  const _TogglesEditor({ super.key, required this.name, required this.toggles });

  @override
  State<_TogglesEditor> createState() => __TogglesEditorState();
}

class __TogglesEditorState extends State<_TogglesEditor> {
  late _StringListTableConfig tableConfig;

  Future<Iterable<AutocompleteConfig>> getAutocompleteOptions() async {
    var sceneStates = await idLookup.getAllSceneStates();
    return sceneStates.map((s) => AutocompleteConfig(
      "${s.key}${s.commentEng.isNotEmpty ? " (${s.commentEng})" : ""}",
      insertText: s.key,
    ));
  }

  @override
  void initState() {
    tableConfig = _StringListTableConfig(widget.name, widget.toggles, getAutocompleteOptions);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return TableEditor(config: tableConfig);
  }
}


const _weaponsByIndex = [
  Tuple2(0x000003EB, "Faith"),
  Tuple2(0x000003F5, "Iron Pipe"),
  Tuple2(0x000003FC, "Beastbane"),
  Tuple2(0x00000410, "Phoenix Dagger"),
  Tuple2(0x00000406, "Ancient Overlord"),
  Tuple2(0x0000041A, "Type-40 Sword"),
  Tuple2(0x00000424, "Type-3 Sword"),
  Tuple2(0x0000042E, "Virtuous Contract"),
  Tuple2(0x0000042F, "Cruel Oath"),
  Tuple2(0x00000438, "YoRHa-issue Blade"),
  Tuple2(0x00000442, "Machine Sword"),
  Tuple2(0x000004B3, "Iron Will"),
  Tuple2(0x000004BD, "Fang of the Twins"),
  Tuple2(0x000004C4, "Beastlord"),
  Tuple2(0x000004CE, "Phoenix Sword"),
  Tuple2(0x000004D8, "Type-40 Blade"),
  Tuple2(0x000004E2, "Type-3 Blade"),
  Tuple2(0x000004EC, "Virtuous Treaty"),
  Tuple2(0x000004ED, "Cruel Blood Oath"),
  Tuple2(0x000004F6, "Machine Axe"),
  Tuple2(0x00000578, "Phoenix Lance"),
  Tuple2(0x0000058C, "Beastcurse"),
  Tuple2(0x00000596, "Dragoon Lance"),
  Tuple2(0x000005A0, "Spear of the Usurper"),
  Tuple2(0x000005AA, "Type-40 Lance"),
  Tuple2(0x000005B4, "Type-3 Lance"),
  Tuple2(0x000005BE, "Virtuous Dignity"),
  Tuple2(0x000005BF, "Cruel Arrogance"),
  Tuple2(0x000005C8, "Machine Spear"),
  Tuple2(0x00000668, "Angel's Folly"),
  Tuple2(0x0000065E, "Demon's Cry"),
  Tuple2(0x0000064A, "Type-40 Fists"),
  Tuple2(0x00000640, "Type-3 Fists"),
  Tuple2(0x00000654, "Virtuous Grief"),
  Tuple2(0x00000655, "Cruel Lament"),
  Tuple2(0x00000672, "Machine Heads"),
  Tuple2(0x00000753, "Engine Blade"),
  Tuple2(0x00000754, "Cypress Stick"),
  Tuple2(0x00000755, "Emil Heads"),
];
